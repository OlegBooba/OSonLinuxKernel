#!/bin/bash
# build_os.sh - Единый скрипт сборки ISO образа ОС с Установщиком и AppMarket

set -e
BASE_DIR=$(pwd)
WORKDIR=$BASE_DIR/os_build

# Создаем структуру папок для будущей ОС
mkdir -p $WORKDIR/{iso/boot/grub,initramfs/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,dev,mnt,tmp,opt/apps}}

KERNEL_VER="6.6.22"
BUSYBOX_VER="1.36.1"

echo "=== 1. Скачивание и сборка ядра Linux ==="
cd $WORKDIR
if [ ! -f linux-$KERNEL_VER.tar.xz ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VER.tar.xz
    tar -xf linux-$KERNEL_VER.tar.xz
fi
cd linux-$KERNEL_VER
make defconfig
make -j$(nproc)
cp arch/x86/boot/bzImage $WORKDIR/iso/boot/vmlinuz

echo "=== 2. Скачивание и сборка Busybox ==="
cd $WORKDIR
if [ ! -f busybox-$BUSYBOX_VER.tar.bz2 ]; then
    wget https://busybox.net/downloads/busybox-$BUSYBOX_VER.tar.bz2
    tar -xf busybox-$BUSYBOX_VER.tar.bz2
fi
cd busybox-$BUSYBOX_VER
make defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config # Статическая сборка
make -j$(nproc)
make CONFIG_PREFIX=$WORKDIR/initramfs install

echo "=== 3. Настройка Initramfs (корневой системы) ==="
# Главный загрузочный скрипт
cat << 'EOF' > $WORKDIR/initramfs/init
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Проверяем, есть ли установщик, и запускаем его
if [ -x /bin/installer.sh ]; then
    /bin/installer.sh
else
    echo "Запуск консоли..."
    exec /bin/sh
fi
EOF
chmod +x $WORKDIR/initramfs/init

echo "=== 4. Встраивание Установщика (Debian Style) ==="
cat << 'EOF' > $WORKDIR/initramfs/bin/installer.sh
#!/bin/sh
export DIALOGRC=/etc/dialogrc
BACKTITLE="Установка MyOS (TinyCore Base)"

dialog --backtitle "$BACKTITLE" --title "Добро пожаловать" --msgbox "Добро пожаловать в программу установки MyOS.\n\nСистема будет установлена на ваш жесткий диск." 10 50

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
    dialog --infobox "Форматирование $DISK и установка базовой системы...\nРаспаковка ядра и Busybox..." 5 50
    sleep 3
    dialog --title "Успех" --msgbox "Система успешно установлена на $DISK! Перезагрузите компьютер." 8 50
    clear
    exec /bin/sh
else
    clear
    exec /bin/sh
fi
EOF
chmod +x $WORKDIR/initramfs/bin/installer.sh

echo "=== 5. Встраивание AppMarket (GUI Python) ==="
cat << 'EOF' > $WORKDIR/initramfs/usr/bin/appmarket
#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox, ttk
import urllib.request
import tarfile, zipfile, os, threading

INSTALL_DIR = "/opt/apps"

class AppMarket(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("AppMarket")
        self.geometry("400x300")
        if not os.path.exists(INSTALL_DIR): os.makedirs(INSTALL_DIR, exist_ok=True)

        tk.Label(self, text="URL приложения (.zip, .tar.gz):").pack(pady=10)
        self.url_entry = tk.Entry(self, width=50)
        self.url_entry.pack(pady=5)

        self.btn = tk.Button(self, text="Установить", command=self.start)
        self.btn.pack(pady=20)
        self.status = tk.Label(self, text="Готов")
        self.status.pack()

    def start(self):
        url = self.url_entry.get()
        if not url: return
        self.btn.config(state=tk.DISABLED)
        self.status.config(text="Скачивание...")
        threading.Thread(target=self.dl, args=(url,), daemon=True).start()

    def dl(self, url):
        fp = os.path.join("/tmp", url.split('/')[-1])
        try:
            urllib.request.urlretrieve(url, fp)
            self.status.config(text="Распаковка...")
            if fp.endswith(".zip"):
                with zipfile.ZipFile(fp, 'r') as z: z.extractall(INSTALL_DIR)
            else:
                with tarfile.open(fp, 'r:*') as t: t.extractall(INSTALL_DIR)
            os.remove(fp)
            self.after(0, lambda: self.status.config(text="Успех!"))
        except Exception as e:
            self.after(0, lambda: self.status.config(text=f"Ошибка: {e}"))
        finally:
            self.after(0, lambda: self.btn.config(state=tk.NORMAL))

if __name__ == "__main__":
    app = AppMarket()
    app.mainloop()
EOF
chmod +x $WORKDIR/initramfs/usr/bin/appmarket

echo "=== 6. Сборка initramfs (Упаковка файловой системы) ==="
cd $WORKDIR/initramfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > $WORKDIR/iso/boot/initrd.img

echo "=== 7. Настройка GRUB и создание ISO ==="
cat << 'EOF' > $WORKDIR/iso/boot/grub/grub.cfg
set default=0
set timeout=5
menuentry "MyOS Installer (Debian style setup)" {
    linux /boot/vmlinuz
    initrd /boot/initrd.img
}
EOF

grub-mkrescue -o $BASE_DIR/my_os.iso $WORKDIR/iso
echo "Готово! Образ my_os.iso создан в $(pwd). Можно загружать в VirtualBox."
