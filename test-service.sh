#!/bin/bash

echo "=== 1. Остановка службы ==="
sudo systemctl stop dedup-service

echo "=== 2. Создание тестовых данных ==="
sudo rm -rf /tmp/test-dedup2
mkdir -p /tmp/test-dedup2
cd /tmp/test-dedup2

# Создаем дубликаты
echo "This is duplicate file 1" > file1.txt
cp file1.txt file2.txt
cp file1.txt file3.txt
echo "Different file" > file4.txt

echo "Файлы до дедупликации:"
ls -li

echo -e "\n=== 3. Настройка конфигурации ==="
sudo tee /etc/dedup-service.conf << 'CONFIG'
path=/tmp/test-dedup2
scan_interval=5
min_file_size=1
dry_run=false
verbose=true
CONFIG

echo -e "\n=== 4. Запуск службы ==="
sudo systemctl start dedup-service

echo -e "\n=== 5. Ожидание сканирования (10 секунд) ==="
sleep 10

echo -e "\n=== 6. Проверка результатов ==="
echo "Файлы после дедупликации:"
ls -li

echo -e "\n=== 7. Проверка логов ==="
sudo journalctl -u dedup-service --since "1 minute ago" | grep -i "hard link\|replaced\|user-12-24"

echo -e "\n=== 8. Проверка inode номеров ==="
INODE1=$(ls -i file1.txt | awk '{print $1}')
INODE2=$(ls -i file2.txt | awk '{print $1}')
INODE3=$(ls -i file3.txt | awk '{print $1}')

if [ "$INODE1" = "$INODE2" ] && [ "$INODE1" = "$INODE3" ]; then
    echo "✅ УСПЕХ: Все дубликаты имеют одинаковый inode ($INODE1)"
    echo "Дедупликация работает корректно!"
else
    echo "❌ ОШИБКА: Inode не совпадают"
    echo "file1.txt: $INODE1"
    echo "file2.txt: $INODE2"  
    echo "file3.txt: $INODE3"
fi

echo -e "\n=== 9. Остановка службы ==="
sudo systemctl stop dedup-service

echo -e "\n=== 10. Восстановление оригинального конфига ==="
sudo tee /etc/dedup-service.conf << 'CONFIG'
path=/home
path=/var/www
scan_interval=3600
min_file_size=1024
dry_run=false
verbose=false
CONFIG
