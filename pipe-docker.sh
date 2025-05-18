#!/bin/bash

# Проверяем, запущен ли скрипт от имени root
if [ "$EUID" -ne 0 ]; then 
    echo "Пожалуйста, запустите скрипт с правами root (используйте sudo)"
    exit 1
fi

# Назначаем права на выполнение текущему скрипту
chmod 755 "$0"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Директории для логов и резервных копий
LOG_FILE="/var/log/pipe_testnet_docker.log"
BACKUP_DIR="/root/pipe_node_backup"
DOCKER_CONFIG_DIR="/root/pipe_docker_config"
DOCKER_CONTAINER_NAME="pipe-network-testnet"
DOCKER_VOLUME_NAME="pipe-network-data"

# Массивы для генерации имен
node_prefixes=("Pipe" "Validator" "Cosmos" "Galaxy" "Orbit" "Stellar" "Space" "Crypto" "Block" "Digital" "Cyber" "Network" "Quantum" "Tech" "Cloud")
node_suffixes=("Node" "Point" "Validator" "Hub" "Station" "Portal" "Gateway" "Edge" "Server" "Relay" "Bridge")
node_adjectives=("Fast" "Stable" "Secure" "Power" "Main" "Prime" "Core" "Ultra" "Mega" "Super" "Hyper" "Smart")

random_names=(
    "Alex" "Maria" "Dmitry" "Elena" "Ivan" "Olga" "Sergey" "Anna" "Pavel" "Natalia"
    "Michael" "Ekaterina" "Andrey" "Svetlana" "Nikolay" "Tatiana" "Vladimir" "Julia" "Alexey" "Victoria"
    "Denis" "Irina" "Anton" "Yulia" "Roman" "Sofia" "Maxim" "Anastasia" "Artem" "Daria"
    "Evgeny" "Polina" "Ilya" "Marina" "Oleg" "Ksenia" "Kirill" "Alina" "Nikita" "Christina"
    "Mikhail" "Valentina" "Danila" "Kate" "Gregory" "Vera" "Victor" "Veronika" "Ruslan" "Elizaveta"
    "Igor" "Vasilisa" "Arthur" "Sofia" "Leonid" "Diana" "Eduard" "Alena" "Vadim" "Yana"
    "Mark" "Eva" "Timur" "Kristina" "Fedor" "Alexandra" "George" "Kira" "Boris" "Varvara"
    "Semyon" "Ada" "Yaroslav" "Angelina" "Matvey" "Ulyana" "Philip" "Antonina" "Lev" "Tamara"
    "Bogdan" "Emilia" "Stanislav" "Miroslava" "Arseniy" "Regina" "Egor" "Karina" "Peter" "Milana"
    "John" "Sarah" "David" "Emma" "Robert" "Olivia" "William" "Ava" "Richard" "Sophia"
)

# Функция для логирования
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    echo -e "$message"
}

# Функция для отображения главного меню
show_menu() {
    clear
    echo -e "${BLUE}=== Pipe Network Testnet Docker - Управление нодой ===${NC}"
    echo -e "${GREEN}Присоединяйтесь к нашему Telegram каналу: ${BLUE}@nodetrip${NC}"
    echo -e "${GREEN}Гайды по нодам, новости, обновления и помощь${NC}"
    echo "------------------------------------------------"
    echo "1. Установить ноду Testnet в Docker"
    echo "2. Мониторинг ноды Docker"
    echo "3. Удалить ноду Docker"
    echo "4. Создать резервную копию данных ноды"
    echo "5. Просмотреть логи установки"
    echo "6. Просмотреть логи контейнера"
    echo "7. Остановить ноду Devnet (если запущена)"
    echo "0. Выход"
    echo
}

# Функция для просмотра логов установки
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "${BLUE}=== Логи установки ===${NC}"
        cat "$LOG_FILE"
        echo
        echo -e "${BLUE}Логи сохранены в файле: $LOG_FILE${NC}"
    else
        echo -e "${RED}Файл логов не найден${NC}"
    fi
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
}

# Функция для просмотра логов контейнера
show_container_logs() {
    if docker ps -a | grep -q "$DOCKER_CONTAINER_NAME"; then
        echo -e "${BLUE}=== Логи контейнера Pipe Network Testnet ===${NC}"
        docker logs "$DOCKER_CONTAINER_NAME"
    else
        echo -e "${RED}Контейнер $DOCKER_CONTAINER_NAME не найден${NC}"
    fi
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
}

# Функция для остановки ноды devnet
stop_devnet_node() {
    echo -e "${YELLOW}Проверяем наличие ноды Devnet...${NC}"

    if systemctl is-active --quiet pop.service; then
        echo -e "${YELLOW}Останавливаем ноду Pipe Network Devnet...${NC}"
        systemctl stop pop.service
        systemctl disable pop.service
        echo -e "${GREEN}Нода Pipe Network Devnet остановлена и отключена${NC}"
    else
        echo -e "${BLUE}Активная нода Pipe Network Devnet не найдена${NC}"
    fi

    # Также проверяем сервис pipe-pop на всякий случай
    if systemctl is-active --quiet pipe-pop.service; then
        echo -e "${YELLOW}Останавливаем альтернативную ноду Pipe Network Devnet...${NC}"
        systemctl stop pipe-pop.service
        systemctl disable pipe-pop.service
        echo -e "${GREEN}Альтернативная нода Pipe Network Devnet остановлена и отключена${NC}"
    fi
    
    # Проверяем также сервис popcache
    if systemctl is-active --quiet popcache.service; then
        echo -e "${YELLOW}Останавливаем сервис popcache...${NC}"
        systemctl stop popcache.service
        systemctl disable popcache.service
        echo -e "${GREEN}Сервис popcache остановлен и отключен${NC}"
    fi

    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
}

# Функция для установки через Docker
install_docker_node() {
    log_message "${GREEN}Начинаем установку ноды Pipe Network Testnet через Docker...${NC}"

    # Проверяем установлен ли Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker не установлен. Устанавливаем Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl enable docker
        systemctl start docker
    else
        echo -e "${GREEN}Docker уже установлен.${NC}"
    fi

    # Создаем директорию для конфигурации
    mkdir -p "$DOCKER_CONFIG_DIR"
    
    # Автоматически генерируем случайное имя ноды
    prefix_index=$((RANDOM % ${#node_prefixes[@]}))
    suffix_index=$((RANDOM % ${#node_suffixes[@]}))
    adj_index=$((RANDOM % ${#node_adjectives[@]}))
    
    # 50% шанс добавить прилагательное
    if [[ $((RANDOM % 2)) -eq 0 ]]; then
        node_name="${node_adjectives[$adj_index]}${node_prefixes[$prefix_index]}${node_suffixes[$suffix_index]}"
    else
        node_name="${node_prefixes[$prefix_index]}${node_suffixes[$suffix_index]}"
    fi
    
    # 40% шанс добавить 2-3 случайные цифры в конце
    if [[ $((RANDOM % 5)) -lt 2 ]]; then
        random_digits=$((RANDOM % 900 + 100))
        node_name="${node_name}${random_digits}"
    fi
    
    echo -e "${GREEN}Имя ноды автоматически установлено: $node_name${NC}"
    
    # Имя POP совпадает с именем ноды
    pop_name="$node_name"
    echo -e "${GREEN}Имя POP-ноды автоматически установлено: $pop_name${NC}"
    
    # Автоматически генерируем случайное имя пользователя
    random_index=$((RANDOM % ${#random_names[@]}))
    
    # Создаем имя без хеша, возможно добавляя случайный суффикс
    if [[ $((RANDOM % 3)) -eq 0 ]]; then
        # 33% шанс добавить какой-то распространенный суффикс
        suffixes=("dev" "validator" "node" "crypto" "web3" "defi" "tech" "pro" "net" "sys")
        suffix_index=$((RANDOM % ${#suffixes[@]}))
        user_name="${random_names[$random_index]}_${suffixes[$suffix_index]}"
    else
        # Возможно добавляем одну-две цифры (30% шанс)
        if [[ $((RANDOM % 10)) -lt 3 ]]; then
            random_digit=$((RANDOM % 99 + 1))
            user_name="${random_names[$random_index]}${random_digit}"
        else
            user_name="${random_names[$random_index]}"
        fi
    fi
    
    echo -e "${GREEN}Имя пользователя автоматически установлено: $user_name${NC}"
    
    # Автоматическое определение местоположения
    echo -e "${BLUE}Определяем местоположение сервера...${NC}"
    
    # Устанавливаем jq, если не установлен
    if ! command -v jq &> /dev/null; then
        apt install -y jq
    fi
    
    # Автоматическое определение местоположения через IP
    auto_location=$(curl -s https://ipinfo.io/json | jq -r '.region + ", " + .country')
    echo -e "${GREEN}🌍 Автоматически определенное местоположение: $auto_location${NC}"
    
    read -p "Использовать автоматически определённое местоположение? (y/n): " use_auto_location
    
    if [[ $use_auto_location == "y" || $use_auto_location == "Y" ]]; then
        pop_location="$auto_location"
    else
        read -p "Введите местоположение ноды (город, страна): " pop_location
    fi
    
    # Запрашиваем информацию у пользователя
    echo -e "${BLUE}Теперь создадим конфигурационный файл с оставшейся информацией${NC}"
    echo
    read -p "Введите ваш пригласительный код из письма: " invite_code
    read -p "Введите ваш адрес электронной почты: " email
    read -p "Введите ваш веб-сайт (или нажмите Enter для пропуска): " website
    read -p "Введите ваше имя пользователя Discord (или нажмите Enter для пропуска): " discord
    read -p "Введите ваш ник Telegram (или нажмите Enter для пропуска): " telegram
    read -p "Введите ваш публичный ключ Solana (адрес кошелька): " solana_pubkey

    # Автоматическая настройка параметров кэширования с рекомендуемыми значениями
    memory_cache_size=4096
    echo -e "${GREEN}Размер кэша в оперативной памяти автоматически установлен: ${memory_cache_size} МБ${NC}"

    disk_cache_size=100
    echo -e "${GREEN}Размер дискового кэша автоматически установлен: ${disk_cache_size} ГБ${NC}"

    # Создаем конфигурационный файл
    echo -e "${GREEN}Создаем конфигурационный файл...${NC}"
    cat > "$DOCKER_CONFIG_DIR/config.json" << EOL
{
  "pop_name": "$pop_name",
  "pop_location": "$pop_location",
  "invite_code": "$invite_code",
  "server": {
    "host": "0.0.0.0",
    "port": 443,
    "http_port": 80,
    "workers": 40
  },
  "cache_config": {
    "memory_cache_size_mb": $memory_cache_size,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": $disk_cache_size,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {
    "base_url": "https://dataplane.pipenetwork.com"
  },
  "identity_config": {
    "node_name": "$node_name",
    "name": "$user_name",
    "email": "$email",
    "website": "$website",
    "discord": "$discord",
    "telegram": "$telegram",
    "solana_pubkey": "$solana_pubkey"
  }
}
EOL

    # Создаем Docker volume для данных кэша
    echo -e "${GREEN}Создаем Docker volume для данных...${NC}"
    docker volume create "$DOCKER_VOLUME_NAME"

    # Останавливаем существующий контейнер, если такой есть
    if docker ps -a | grep -q "$DOCKER_CONTAINER_NAME"; then
        echo -e "${YELLOW}Останавливаем существующий контейнер...${NC}"
        docker stop "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
        docker rm "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
    fi

    # Открываем порты в фаерволе
    if command -v ufw &> /dev/null; then
        echo -e "${BLUE}Открываем порты в фаерволе...${NC}"
        ufw allow 80/tcp
        ufw allow 443/tcp
    fi

    # Запускаем контейнер Docker (используя Ubuntu 22.04 вместо 24.04)
    echo -e "${GREEN}Запускаем контейнер Docker с нодой Pipe Network...${NC}"
    docker run -d \
        --name "$DOCKER_CONTAINER_NAME" \
        --restart always \
        -p 80:80 \
        -p 443:443 \
        -v "$DOCKER_CONFIG_DIR/config.json:/opt/popcache/config.json" \
        -v "$DOCKER_VOLUME_NAME:/opt/popcache/cache" \
        -e POP_CONFIG_PATH=/opt/popcache/config.json \
        --pull always \
        ubuntu:24.04 /bin/bash -c \
        "apt-get update && \
         apt-get install -y curl wget tar && \
         mkdir -p /opt/popcache/logs && \
         cd /opt/popcache && \
         wget https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz && \
         tar -xzf pop-v0.3.0-linux-*.tar.gz && \
         chmod 755 /opt/popcache/pop && \
         /opt/popcache/pop"

    # Проверяем, запустился ли контейнер успешно
    sleep 5
    if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
        echo -e "${GREEN}Контейнер успешно запущен!${NC}"
        
        # Автоматический перезапуск контейнера для решения проблемы с регистрацией
        echo -e "${YELLOW}Проверка статуса регистрации...${NC}"
        
        # Проверка работоспособности ноды
        if ! curl -sk "http://localhost/health" | grep -q "status.*ok"; then
            echo -e "${YELLOW}Нода не отвечает. Возможны проблемы с регистрацией.${NC}"
            echo -e "${BLUE}Автоматический перезапуск контейнера через 10 секунд...${NC}"
            sleep 10
            echo -e "${BLUE}Перезапуск контейнера...${NC}"
            docker restart "$DOCKER_CONTAINER_NAME" > /dev/null
            echo -e "${GREEN}Контейнер перезапущен.${NC}"
            echo -e "${YELLOW}Ожидание запуска ноды (20 секунд)...${NC}"
            sleep 20
        else
            echo -e "${GREEN}Нода успешно зарегистрирована и работает.${NC}"
        fi
        
        echo -e "${BLUE}Проверьте работу ноды:${NC}"
        echo -e "${YELLOW}Состояние: http://$(hostname -I | awk '{print $1}')/state${NC}"
        echo -e "${YELLOW}Проверка здоровья: http://$(hostname -I | awk '{print $1}')/health${NC}"
        echo -e "${GREEN}Нода Pipe Network Testnet успешно установлена через Docker!${NC}"
    else
        echo -e "${RED}Возникла проблема при запуске контейнера Docker.${NC}"
        echo -e "${YELLOW}Проверьте логи контейнера: docker logs $DOCKER_CONTAINER_NAME${NC}"
    fi

    # Создаем резервную копию конфигурации
    mkdir -p "$BACKUP_DIR"
    cp -r "$DOCKER_CONFIG_DIR" "$BACKUP_DIR"
    echo -e "${BLUE}Конфигурация сохранена в $BACKUP_DIR${NC}"

    read -p "Нажмите любую клавишу для возврата в меню..." -n1 -s
    clear
}

# Функция мониторинга ноды в Docker
monitor_docker_node() {
    if ! docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
        echo -e "${RED}Контейнер $DOCKER_CONTAINER_NAME не запущен${NC}"
        read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
        return
    fi

    clear
    echo -e "${BLUE}=== Мониторинг ноды Pipe Network в Docker ===${NC}"
    echo
    
    # Проверка статуса контейнера
    echo -e "${YELLOW}Статус контейнера:${NC}"
    docker ps --filter "name=$DOCKER_CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    # Получение IP-адреса сервера
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${BLUE}Доступные проверки:${NC}"
    echo -e "${YELLOW}1. Состояние ноды: http://$SERVER_IP/state${NC}"
    echo -e "${YELLOW}2. Проверка здоровья: http://$SERVER_IP/health${NC}"
    echo

    # Использование curl для получения статуса
    echo -e "${GREEN}Выполняем проверку состояния...${NC}"
    if command -v curl &> /dev/null; then
        echo "Состояние ноды:"
        curl -s "http://$SERVER_IP/state" || echo -e "${RED}Не удалось получить состояние${NC}"
        echo
        echo "Проверка здоровья:"
        curl -s "http://$SERVER_IP/health" || echo -e "${RED}Не удалось выполнить проверку здоровья${NC}"
    else
        echo -e "${RED}Утилита curl не установлена. Установите её командой: apt install curl${NC}"
    fi

    echo
    echo -e "${BLUE}Статистика использования ресурсов контейнером:${NC}"
    docker stats --no-stream "$DOCKER_CONTAINER_NAME"
    
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
}

# Функция удаления ноды Docker
remove_docker_node() {
    echo -e "${RED}Внимание! Вы собираетесь удалить ноду Pipe Network из Docker!${NC}"
    echo -e "${YELLOW}Это действие остановит контейнер, удалит его и все данные.${NC}"
    read -p "Вы уверены, что хотите продолжить? (y/n): " choice
    
    if [[ $choice != "y" && $choice != "Y" ]]; then
        echo -e "${BLUE}Удаление отменено.${NC}"
        read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
        return
    fi
    
    # Останавливаем и удаляем контейнер
    if docker ps -a | grep -q "$DOCKER_CONTAINER_NAME"; then
        echo -e "${YELLOW}Останавливаем и удаляем контейнер...${NC}"
        docker stop "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
        docker rm "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
        log_message "${GREEN}Контейнер Pipe Network Testnet остановлен и удален${NC}"
    else
        echo -e "${BLUE}Контейнер $DOCKER_CONTAINER_NAME не найден${NC}"
    fi
    
    # Спрашиваем про удаление volume
    read -p "Удалить Docker volume с данными ноды? (y/n): " volume_choice
    if [[ $volume_choice == "y" || $volume_choice == "Y" ]]; then
        if docker volume ls | grep -q "$DOCKER_VOLUME_NAME"; then
            docker volume rm "$DOCKER_VOLUME_NAME" >/dev/null 2>&1
            log_message "${GREEN}Volume $DOCKER_VOLUME_NAME удален${NC}"
        fi
    else
        echo -e "${BLUE}Docker volume $DOCKER_VOLUME_NAME сохранен${NC}"
    fi
    
    # Спрашиваем про удаление конфигурации
    read -p "Удалить конфигурационные файлы? (y/n): " config_choice
    if [[ $config_choice == "y" || $config_choice == "Y" ]]; then
        if [ -d "$DOCKER_CONFIG_DIR" ]; then
            rm -rf "$DOCKER_CONFIG_DIR"
            log_message "${GREEN}Директория конфигурации $DOCKER_CONFIG_DIR удалена${NC}"
        fi
    else
        echo -e "${BLUE}Конфигурационные файлы в $DOCKER_CONFIG_DIR сохранены${NC}"
    fi
    
    echo -e "${GREEN}Удаление ноды Pipe Network Testnet из Docker завершено${NC}"
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
}

# Функция резервного копирования данных ноды
backup_docker_node() {
    echo -e "${BLUE}=== Создание резервной копии данных ноды Pipe Network в Docker ===${NC}"
    
    # Проверяем, существует ли конфигурация
    if [ -f "$DOCKER_CONFIG_DIR/config.json" ]; then
        # Создаем директорию для резервной копии
        BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_PATH="$BACKUP_DIR/pipe_docker_backup_$BACKUP_DATE"
        mkdir -p "$BACKUP_PATH"
        
        echo -e "${YELLOW}Создаем резервную копию конфигурации...${NC}"
        cp -r "$DOCKER_CONFIG_DIR/config.json" "$BACKUP_PATH/"
        
        # Если контейнер запущен, создаем архив Docker volume
        if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
            echo -e "${YELLOW}Контейнер запущен. Создаем архив данных...${NC}"
            # Создаем временный контейнер для архивации данных
            docker run --rm -v "$DOCKER_VOLUME_NAME:/data" -v "$BACKUP_PATH:/backup" ubuntu:24.04 \
                bash -c "cd /data && tar czf /backup/pipe_data.tar.gz ."
            
            if [ -f "$BACKUP_PATH/pipe_data.tar.gz" ]; then
                echo -e "${GREEN}Резервная копия данных успешно создана в $BACKUP_PATH/pipe_data.tar.gz${NC}"
                log_message "Создана резервная копия данных Docker ноды в $BACKUP_PATH"
            else
                echo -e "${RED}Ошибка при создании архива данных${NC}"
            fi
        else
            echo -e "${YELLOW}Контейнер не запущен. Сохраняем только конфигурацию.${NC}"
        fi
        
        echo -e "${GREEN}Резервная копия создана в $BACKUP_PATH${NC}"
    else
        echo -e "${RED}Конфигурация ноды не найдена в $DOCKER_CONFIG_DIR/config.json${NC}"
    fi
    
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
}

# Основной цикл меню
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_docker_node ;;
        2) monitor_docker_node ;;
        3) remove_docker_node ;;
        4) backup_docker_node ;;
        5) show_logs ;;
        6) show_container_logs ;;
        7) stop_devnet_node ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac
done
