#!/bin/bash

cd ~/dedup-service

echo "=== Очистка ==="
rm -rf ~/rpmbuild
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "=== Создание архива ==="
cd /tmp
rm -rf dedup-service-1.0
mkdir dedup-service-1.0

# Копируем файлы
cp ~/dedup-service/SOURCES/dedup-service.c dedup-service-1.0/
cp ~/dedup-service/SOURCES/dedup-service.conf dedup-service-1.0/
cp ~/dedup-service/SOURCES/dedup-service.service dedup-service-1.0/
cp ~/dedup-service/LICENSE dedup-service-1.0/
cp ~/dedup-service/README.md dedup-service-1.0/

# Создаем архив
tar -czf dedup-service-1.0.tar.gz dedup-service-1.0/
cp dedup-service-1.0.tar.gz ~/rpmbuild/SOURCES/

echo "=== Создание spec файла ==="
cat > ~/rpmbuild/SPECS/dedup-service.spec << 'SPEC'
Name:           dedup-service
Version:        1.0
Release:        1
Summary:        File deduplication service
License:        GPLv3+
URL:            http://localhost
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  xxhash-devel
Requires:       xxhash-libs

# Отключить debuginfo
%define debug_package %{nil}
%define _enable_debug_package 0

%description
A system service that finds duplicate files and replaces them with hard links.

%prep
%setup -q

%build
gcc -O2 -Wall -Wextra dedup-service.c -o dedup-service -lxxhash

%install
mkdir -p %{buildroot}/usr/sbin
mkdir -p %{buildroot}/etc
mkdir -p %{buildroot}/usr/lib/systemd/system

install -m 750 dedup-service %{buildroot}/usr/sbin/
install -m 644 dedup-service.conf %{buildroot}/etc/
install -m 644 dedup-service.service %{buildroot}/usr/lib/systemd/system/

%files
%attr(750, root, root) /usr/sbin/dedup-service
%config(noreplace) /etc/dedup-service.conf
/usr/lib/systemd/system/dedup-service.service

%changelog
* Thu Dec 05 2024 Student <student@edu> - 1.0-1
- Initial package
SPEC

echo "=== Сборка RPM ==="
cd ~/rpmbuild/SPECS

# Собираем без debuginfo
rpmbuild -ba --nodebuginfo dedup-service.spec

echo -e "\n=== Результат ==="
if find ~/rpmbuild -name "*.rpm" -type f 2>/dev/null | grep -q .; then
    echo "✅ RPM пакет успешно создан!"
    echo ""
    echo "Собранные пакеты:"
    find ~/rpmbuild -name "*.rpm" -type f
    
    echo -e "\nИнформация о пакете:"
    RPM_FILE=$(find ~/rpmbuild/RPMS -name "dedup-service-1.0-1*.rpm" -type f | head -1)
    rpm -qip "$RPM_FILE"
    
    echo -e "\nФайлы в пакете:"
    rpm -qlp "$RPM_FILE"
else
    echo "❌ Ошибка сборки RPM"
    exit 1
fi
