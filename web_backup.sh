#!/bin/bash

# Функция для создания временной веб-ссылки для скачивания файлов резервной копии
create_web_backup_link() {
    backup_path="$1"
    backup_file="$2"
    migration_file="$3"
    
    # Создаем информационный файл о миграции, если он не был передан
    if [ -z "$migration_file" ]; then
        migration_file="$backup_path/migration_info.txt"
        echo "=== Информация о резервной копии ===" > "$migration_file"
        echo "Дата создания: $(date)" >> "$migration_file"
        echo "Директория бэкапа: $backup_path" >> "$migration_file"
        
        # Добавляем инструкции по миграции
        echo -e "\n=== ИНСТРУКЦИЯ ПО МИГРАЦИИ ===" >> "$migration_file"
        echo "1. Распакуйте архив pipe_data.tar.gz" >> "$migration_file"
        echo "2. Сохраните файл config.json для настройки на новом сервере" >> "$migration_file"
        echo "3. При переносе на другой сервер обязательно измените местоположение в файле config.json" >> "$migration_file"
        echo "4. Для определения нового местоположения используйте команду: curl -s https://ipinfo.io/json | jq -r '.region + \", \" + .country'" >> "$migration_file"
    fi
    
    # Устанавливаем python если не установлен
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        apt update && apt install -y python3
    fi

    # Определяем команду Python
    if command -v python3 &> /dev/null; then
        PY_CMD="python3"
    else
        PY_CMD="python"
    fi

    # Создаем временную директорию для веб-сервера
    tmp_dir="/tmp/pipe_backup_download"
    mkdir -p "$tmp_dir"
    cp "$backup_file" "$tmp_dir/" 2>/dev/null || true
    cp "$backup_path/config.json" "$tmp_dir/" 2>/dev/null || true
    cp "$backup_path/.pop_state.json" "$tmp_dir/" 2>/dev/null || true
    cp "$migration_file" "$tmp_dir/" 2>/dev/null || true

    # Создаем HTML страницу с кнопками для скачивания
    cat > "$tmp_dir/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Pipe Network Бэкап Ноды</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        h1 {
            color: #0066cc;
            text-align: center;
        }
        .container {
            background-color: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .button {
            display: inline-block;
            background-color: #4CAF50;
            color: white;
            padding: 10px 20px;
            text-align: center;
            text-decoration: none;
            font-size: 16px;
            margin: 10px 5px;
            cursor: pointer;
            border-radius: 4px;
            border: none;
        }
        .warning {
            color: red;
            font-weight: bold;
            text-align: center;
            margin: 20px 0;
        }
        .countdown {
            text-align: center;
            font-size: 18px;
            font-weight: bold;
            margin: 20px 0;
        }
        .file-info {
            margin-bottom: 15px;
            padding: 10px;
            background-color: #f9f9f9;
            border-left: 3px solid #0066cc;
        }
    </style>
</head>
<body>
    <h1>Pipe Network Бэкап Ноды</h1>

    <div class="container">
        <h2>Файлы для скачивания:</h2>

        <div class="file-info">
            <h3>Архив бэкапа</h3>
            <p>Содержит все необходимые файлы для восстановления ноды.</p>
            <a class="button" href="./$(basename "$backup_file")" download>Скачать Архив Бэкапа</a>
        </div>

        <div class="file-info">
            <h3>Конфигурационный файл</h3>
            <p>Файл config.json с настройками ноды.</p>
            <a class="button" href="./config.json" download>Скачать Config</a>
        </div>

        <div class="file-info">
            <h3>Файл состояния ноды</h3>
            <p>Файл .pop_state.json с важными данными о состоянии ноды.</p>
            <a class="button" href="./.pop_state.json" download>Скачать State</a>
        </div>

        <div class="file-info">
            <h3>Инструкция по миграции</h3>
            <p>Текстовый файл с подробными инструкциями по восстановлению ноды на новом сервере.</p>
            <a class="button" href="./$(basename "$migration_file")" download>Скачать Инструкцию</a>
        </div>
    </div>

    <div class="warning">ВНИМАНИЕ! Эта страница будет доступна только 3 минуты!</div>

    <div class="countdown" id="countdown">Осталось времени: 03:00</div>

    <script>
        // Функция обратного отсчета
        var timeLeft = 3 * 60; // 3 минуты в секундах
        var countdownEl = document.getElementById('countdown');

        function updateCountdown() {
            var minutes = Math.floor(timeLeft / 60);
            var seconds = timeLeft % 60;
            countdownEl.innerHTML = 'Осталось времени: ' + 
                (minutes < 10 ? '0' : '') + minutes + ':' + 
                (seconds < 10 ? '0' : '') + seconds;

            if (timeLeft <= 0) {
                countdownEl.innerHTML = 'Время истекло!';
            } else {
                timeLeft--;
                setTimeout(updateCountdown, 1000);
            }
        }

        updateCountdown();
    </script>
</body>
</html>
EOF

    # Запускаем простой HTTP сервер на порту 8090
    SERVER_IP=$(hostname -I | awk '{print $1}')
    PORT=8090

    # Проверяем, занят ли порт
    if netstat -tuln | grep -q ":$PORT "; then
        echo -e "\e[33mПорт $PORT уже занят. Выбираем другой порт...\e[0m"
        # Выбираем другой порт из диапазона 8090-8099
        for TEST_PORT in $(seq 8090 8099); do
            if ! netstat -tuln | grep -q ":$TEST_PORT "; then
                PORT=$TEST_PORT
                echo -e "\e[32mВыбран порт $PORT\e[0m"
                break
            fi
        done
    fi

    # Открываем порт в фаерволе, если он активен
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        ufw allow $PORT/tcp
        echo -e "\e[34mПорт $PORT открыт в фаерволе\e[0m"
    fi

    # Переходим в директорию и запускаем сервер в фоне
    cd "$tmp_dir" && $PY_CMD -m http.server $PORT > "$tmp_dir/server.log" 2>&1 &
    HTTP_PID=$!

    # Проверяем, запустился ли сервер
    sleep 2
    if ! ps -p $HTTP_PID > /dev/null; then
        echo -e "\e[31mОшибка запуска HTTP сервера. Проверьте логи: $tmp_dir/server.log\e[0m"
        cat "$tmp_dir/server.log"
        return 1
    else
        echo -e "\e[32mHTTP сервер успешно запущен с PID: $HTTP_PID\e[0m"
    fi

    # Создаем скрипт автоматического завершения через 3 минуты
    cat > "$tmp_dir/cleanup.sh" << 'EOFSCRIPT'
#!/bin/bash
sleep 180  # Ждем 3 минуты
killall -9 python3 python 2>/dev/null || true
rm -rf /tmp/pipe_backup_download
EOFSCRIPT

    chmod +x "$tmp_dir/cleanup.sh"
    nohup "$tmp_dir/cleanup.sh" > /dev/null 2>&1 &

    echo -e "\n\e[32m✅ Веб-страница для скачивания файлов создана!\e[0m"
    echo -e "\e[34mОткройте в браузере:\e[0m \e[33mhttp://$SERVER_IP:$PORT\e[0m"
    echo -e "\e[32mБудет открыта удобная страница с кнопками для скачивания файлов.\e[0m"
    echo -e "\e[31mВНИМАНИЕ: Страница будет активна только 3 минуты!\e[0m"
    
    return 0
}
