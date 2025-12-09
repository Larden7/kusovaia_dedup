#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <syslog.h>
#include <pwd.h>
#include <grp.h>
#include <limits.h>
#include <xxhash.h>
#include <sys/time.h>
#include <stdbool.h>
#include <signal.h>
#include <stdarg.h>

#define CONFIG_FILE "/etc/dedup-service.conf"
#define DEFAULT_SCAN_DIR "/home"
#define MAX_PATHS 100
#define BUFFER_SIZE 8192
#define HASH_SEED 0

volatile sig_atomic_t stop_daemon = 0;

typedef struct {
    char path[PATH_MAX];
    XXH64_hash_t hash;
    ino_t inode;
    dev_t device;
} FileInfo;

typedef struct {
    char *paths[MAX_PATHS];
    int path_count;
    int scan_interval;
    int min_file_size;
    bool dry_run;
    bool verbose;
} Config;

void signal_handler(int signum) {
    if (signum == SIGTERM || signum == SIGINT) {
        stop_daemon = 1;
    }
}

void setup_signals(void) {
    struct sigaction sa;
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
}

void log_message(const char *format, ...) {
    char message[512];
    va_list args;
    
    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    
    // Получаем реального пользователя (не эффективного)
    uid_t uid = getuid();
    struct passwd *pw = getpwuid(uid);
    if (pw) {
        char full_message[600];
        snprintf(full_message, sizeof(full_message), "[%s] %s", pw->pw_name, message);
        syslog(LOG_INFO, "%s", full_message);
        printf("%s\n", full_message);
    } else {
        syslog(LOG_INFO, "%s", message);
        printf("%s\n", message);
    }
}

Config* load_config(void) {
    Config *config = calloc(1, sizeof(Config));
    if (!config) return NULL;
    
    // Default values
    config->scan_interval = 3600;
    config->min_file_size = 1024;
    config->dry_run = false;
    config->verbose = false;
    
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (!fp) {
        config->paths[0] = strdup(DEFAULT_SCAN_DIR);
        config->path_count = 1;
        return config;
    }
    
    char line[PATH_MAX + 50];
    while (fgets(line, sizeof(line), fp) && config->path_count < MAX_PATHS) {
        line[strcspn(line, "\n")] = 0;
        
        if (strncmp(line, "path=", 5) == 0) {
            config->paths[config->path_count] = strdup(line + 5);
            config->path_count++;
        } else if (strncmp(line, "scan_interval=", 14) == 0) {
            config->scan_interval = atoi(line + 14);
        } else if (strncmp(line, "min_file_size=", 14) == 0) {
            config->min_file_size = atoi(line + 14);
        } else if (strncmp(line, "dry_run=", 8) == 0) {
            config->dry_run = (strcmp(line + 8, "true") == 0);
        } else if (strncmp(line, "verbose=", 8) == 0) {
            config->verbose = (strcmp(line + 8, "true") == 0);
        }
    }
    
    fclose(fp);
    
    if (config->path_count == 0) {
        config->paths[0] = strdup(DEFAULT_SCAN_DIR);
        config->path_count = 1;
    }
    
    return config;
}

XXH64_hash_t calculate_hash(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) return 0;
    
    XXH64_state_t *state = XXH64_createState();
    XXH64_reset(state, HASH_SEED);
    
    unsigned char buffer[BUFFER_SIZE];
    size_t bytes_read;
    
    while ((bytes_read = fread(buffer, 1, BUFFER_SIZE, file)) > 0) {
        XXH64_update(state, buffer, bytes_read);
    }
    
    XXH64_hash_t hash = XXH64_digest(state);
    XXH64_freeState(state);
    fclose(file);
    
    return hash;
}

void scan_directory(const char *dirpath, FileInfo **files, int *count, int *capacity, 
                   int min_size) {
    DIR *dir = opendir(dirpath);
    if (!dir) return;
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL && !stop_daemon) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        
        char fullpath[PATH_MAX];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", dirpath, entry->d_name);
        
        struct stat statbuf;
        if (lstat(fullpath, &statbuf) == -1) continue;
        
        if (S_ISDIR(statbuf.st_mode)) {
            scan_directory(fullpath, files, count, capacity, min_size);
        } else if (S_ISREG(statbuf.st_mode) && statbuf.st_size >= min_size && 
                   statbuf.st_nlink == 1) {
            
            if (*count >= *capacity) {
                *capacity *= 2;
                *files = realloc(*files, *capacity * sizeof(FileInfo));
            }
            
            FileInfo *file = &(*files)[*count];
            strncpy(file->path, fullpath, PATH_MAX - 1);
            file->path[PATH_MAX - 1] = '\0';
            file->inode = statbuf.st_ino;
            file->device = statbuf.st_dev;
            
            // Calculate hash
            if (access(fullpath, R_OK) == 0) {
                file->hash = calculate_hash(fullpath);
                (*count)++;
            }
        }
    }
    
    closedir(dir);
}

int compare_hash(const void *a, const void *b) {
    const FileInfo *fa = (const FileInfo *)a;
    const FileInfo *fb = (const FileInfo *)b;
    
    if (fa->hash < fb->hash) return -1;
    if (fa->hash > fb->hash) return 1;
    return 0;
}

void deduplicate_files(FileInfo *files, int count, bool dry_run) {
    if (count < 2) return;
    
    qsort(files, count, sizeof(FileInfo), compare_hash);
    
    for (int i = 0; i < count - 1 && !stop_daemon; i++) {
        if (files[i].hash == 0) continue;
        
        int j = i + 1;
        while (j < count && files[i].hash == files[j].hash) {
            // Verify files are actually identical
            char cmd[PATH_MAX + 50];
            snprintf(cmd, sizeof(cmd), "cmp -s \"%s\" \"%s\"", files[i].path, files[j].path);
            
            if (system(cmd) == 0) {
                // Files are identical, create hard link
                if (dry_run) {
                    log_message("DRY RUN: Would replace %s with hard link to %s", 
                               files[j].path, files[i].path);
                } else {
                    char backup[PATH_MAX + 10];
                    snprintf(backup, sizeof(backup), "%s.backup", files[j].path);
                    
                    // Backup original
                    if (rename(files[j].path, backup) == 0) {
                        // Create hard link
                        if (link(files[i].path, files[j].path) == 0) {
                            unlink(backup);
                            log_message("Replaced %s with hard link to %s", 
                                       files[j].path, files[i].path);
                        } else {
                            // Restore backup if link failed
                            rename(backup, files[j].path);
                            log_message("Failed to create hard link for %s", files[j].path);
                        }
                    }
                }
            }
            j++;
        }
    }
}

int main(void) {
    // Check if we have sufficient privileges
    if (geteuid() != 0) {
        fprintf(stderr, "This program must be run with root privileges\n");
        return 1;
    }
    
    // Get real user (not effective)
    uid_t real_uid = getuid();
    struct passwd *pw = getpwuid(real_uid);
    if (!pw) {
        fprintf(stderr, "Failed to get user info\n");
        return 1;
    }
    
    openlog("dedup-service", LOG_PID | LOG_NDELAY, LOG_DAEMON);
    log_message("Dedup service starting for user: %s", pw->pw_name);
    
    setup_signals();
    
    Config *config = load_config();
    if (!config) {
        log_message("Failed to load configuration");
        closelog();
        return 1;
    }
    
    log_message("Starting with %d scan paths, interval: %d seconds", 
               config->path_count, config->scan_interval);
    
    while (!stop_daemon) {
        log_message("Starting scan cycle");
        
        FileInfo *files = NULL;
        int capacity = 1000;
        int count = 0;
        
        files = malloc(capacity * sizeof(FileInfo));
        if (!files) {
            log_message("Memory allocation failed");
            sleep(config->scan_interval);
            continue;
        }
        
        // Scan all configured directories
        for (int i = 0; i < config->path_count && !stop_daemon; i++) {
            log_message("Scanning directory: %s", config->paths[i]);
            scan_directory(config->paths[i], &files, &count, &capacity, 
                          config->min_file_size);
        }
        
        log_message("Found %d candidate files for deduplication", count);
        
        if (count > 1) {
            deduplicate_files(files, count, config->dry_run);
        }
        
        free(files);
        
        if (stop_daemon) break;
        
        log_message("Scan cycle completed, sleeping for %d seconds", config->scan_interval);
        
        // Sleep in small intervals to check for stop signal
        for (int i = 0; i < config->scan_interval && !stop_daemon; i += 10) {
            sleep(10);
        }
    }
    
    // Free config memory
    for (int i = 0; i < config->path_count; i++) {
        free(config->paths[i]);
    }
    free(config);
    
    log_message("Dedup service stopping");
    closelog();
    
    return 0;
}
