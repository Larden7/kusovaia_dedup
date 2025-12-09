Name:           dedup-service
Version:        1.0.0
Release:        1%{?dist}
Summary:        File deduplication service using hard links

License:        GPLv3+
URL:            https://github.com/user-13-XX/dedup-service
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc, make, xxhash-devel, systemd-devel
Requires:       xxhash-libs, systemd

%description
A system service that finds duplicate files in specified directories
and replaces them with hard links to save disk space.

%prep
%setup -q

%build
gcc -O2 -Wall -Wextra SOURCES/dedup-service.c -o dedup-service -lxxhash

%install
mkdir -p %{buildroot}%{_sbindir}
mkdir -p %{buildroot}%{_sysconfdir}
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}%{_sysconfdir}/sysconfig

install -m 755 dedup-service %{buildroot}%{_sbindir}/
install -m 644 SOURCES/dedup-service.conf %{buildroot}%{_sysconfdir}/
install -m 644 SOURCES/dedup-service.service %{buildroot}%{_unitdir}/
install -m 644 SOURCES/dedup-service.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/dedup-service

%post
%{_bindir}/systemctl daemon-reload >/dev/null 2>&1 || :
if [ $1 -eq 1 ] ; then
    # Initial installation
    /usr/bin/getent group dedup >/dev/null || /usr/sbin/groupadd -r dedup
    /usr/bin/getent passwd dedup >/dev/null || \
        /usr/sbin/useradd -r -g dedup -s /sbin/nologin -c "Dedup Service User" dedup
    chown root:dedup %{_sbindir}/dedup-service
    chmod 0750 %{_sbindir}/dedup-service
    echo "Configure /etc/dedup-service.conf before starting the service"
fi

%preun
if [ $1 -eq 0 ]; then
    # Package removal
    %{_bindir}/systemctl stop dedup-service >/dev/null 2>&1 || :
    %{_bindir}/systemctl disable dedup-service >/dev/null 2>&1 || :
fi

%postun
%{_bindir}/systemctl daemon-reload >/dev/null 2>&1 || :

%files
%{_sbindir}/dedup-service
%{_sysconfdir}/dedup-service.conf
%{_unitdir}/dedup-service.service
%{_sysconfdir}/sysconfig/dedup-service
%license LICENSE
%doc README.md

%changelog
* Thu Dec 05 2024 User-13-XX <student@university.edu>
- Initial package
