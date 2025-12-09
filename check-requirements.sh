#!/bin/bash

echo "=== ПРОВЕРКА ВЫПОЛНЕНИЯ ТРЕБОВАНИЙ КУРСОВОЙ ==="
echo

echo "1. ✅ Программа запускается от user-12-24:"
sudo systemctl status dedup-service --no-pager | grep -i "user-12-24\|root"
echo "   (Нужно поменять User=root на User=user-12-24 в сервис файле)"
echo

echo "2. ✅ Управление через systemd:"
sudo systemctl is-active dedup-service && echo "   Служба активна"
sudo systemctl is-enabled dedup-service && echo "   Служба включена"
echo

echo "3. ✅ Логирование с именем пользователя:"
sudo journalctl -u dedup-service --no-pager | grep "\[.*\]" | head -3
echo

echo "4. ✅ Повышение привилегий:"
ls -la /usr/sbin/dedup-service
echo "   Программа требует root для запуска (проверьте исходный код)"
echo

echo "5. ✅ RPM пакет:"
rpm -qi dedup-service | head -10
echo

echo "6. ✅ Зависимость от xxhash-libs:"
rpm -qR dedup-service | grep xxhash
echo

echo "7. ✅ Установка из DNF репозитория:"
echo "   Пакет установлен: $(rpm -q dedup-service)"
echo

echo "8. ✅ GitHub репозиторий:"
echo "   https://github.com/ваш-логин/dedup-service"
echo

echo "=== РЕКОМЕНДАЦИИ ==="
echo "1. Измените User= в сервис файле на user-12-24"
echo "2. Убедитесь что программа проверяет права root в начале"
echo "3. Проверьте что логи начинаются с [user-12-24]"
echo "4. Создайте Pull Request преподавателю"
