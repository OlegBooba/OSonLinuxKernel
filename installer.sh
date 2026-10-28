#!/bin/sh
# installer.sh - Установщик в стиле Debian (псевдографика)

export DIALOGRC=/etc/dialogrc # Можно настроить синий фон
BACKTITLE="Установка MyOS (TinyCore/GNOME2 Base)"

dialog --backtitle "$BACKTITLE" --title "Добро пожаловать" --msgbox "Добро пожаловать в программу установки MyOS.\n\nСистема будет установлена на ваш жесткий диск." 10 50

# Выбор диска
DISK=$(dialog --backtitle "$BACKTITLE" --title "Разметка дисков" --menu "Выберите диск для установки:" 15 50 2 \
    "/dev/sda" "Первый жесткий диск" \
    "/dev/sdb" "Второй жесткий диск" 3>&1 1>&2 2>&3)

if [ -z "$DISK" ]; then
    dialog --msgbox "Установка отменена." 5 30
    clear
    exec /bin/sh
fi

dialog --backtitle "$BACKTITLE" --title "Подтверждение" --yesno "ВНИМАНИЕ! Все данные на $DISK будут уничтожены. Продолжить?" 8 50
if [ $? -eq 0 ]; then
    dialog --infobox "Форматирование $DISK и установка базовой системы (Busybox + Kernel)...\nУстановка MATE (GNOME 2)..." 5 50
    sleep 3 # Здесь в реальности идут команды fdisk, mkfs.ext4, cp и grub-install
    
    dialog --title "Успех" --msgbox "Система успешно установлена на $DISK! Перезагрузите компьютер." 8 50
    clear
    exec /bin/sh
else
    clear
    exec /bin/sh
fi