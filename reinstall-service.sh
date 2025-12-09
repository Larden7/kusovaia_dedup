#!/bin/bash

echo "=== 1. Остановка старой службы ==="
sudo systemctl stop dedup-service 2>/dev/null || true
sudo systemctl disable dedup-service 2>/dev/null || true

echo "=== 2. Удаление старого пакета ==="
sudo rpm -e dedup-service 2>/dev/null || true

echo "=== 3. Пересборка RPM ==="
cd ~/rpmbuild/SPECS
rpmbuild -ba --nodebuginfo dedup-service.spec

echo "=== 4. Установка нового пакета ==="
RPM_FILE=$(find ~/rpmbuild/RPMS -name "dedup-service-1.0-1*.rpm" -type f | head -1)
if [ -n "$RPM_FILE" ]; then
    sudo rpm -ivh "$RPM_FILE"
else
    echo "Ошибка: RPM файл не найден"
    exit 1
fi

echo "=== 5. Настройка службы ==="
# Убедимся что сервисный файл правильный
sudo tee /usr/lib/systemd/system/dedup-service.service > /dev/null << 'SERVICE'
[Unit]
Description=Deduplication File Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/dedup-service
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

echo "=== 6. Перезагрузка systemd ==="
sudo systemctl daemon-reload

echo "=== 7. Включение и запуск службы ==="
sudo systemctl enable dedup-service
sudo systemctl start dedup-service

echo "=== 8. Проверка статуса ==="
sudo systemctl status dedup-service --no-pager

echo "=== 9. Создание тестовых файлов ==="
sudo mkdir -p /tmp/test-dedup
echo "Test file content" | sudo tee /tmp/test-dedup/file1.txt > /dev/null
sudo cp /tmp/test-dedup/file1.txt /tmp/test-dedup/file2.txt
sudo cp /tmp/test-dedup/file1.txt /tmp/test-dedup/file3.txt

echo "Тестовые файлы созданы в /tmp/test-dedup/"
ls -li /tmp/test-dedup/

echo -e "\n=== 10. Проверка логов (последние 10 строк) ==="
sudo journalctl -u dedup-service -n 10 --no-pager 2>/dev/null || echo "Логи пока пусты"
