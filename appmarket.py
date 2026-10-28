#!/usr/bin/env python3
# appmarket.py - Простой магазин приложений для распаковки tar/zip

import tkinter as tk
from tkinter import messagebox, ttk
import urllib.request
import tarfile
import zipfile
import os
import threading

INSTALL_DIR = "/opt/apps"

class AppMarket(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("AppMarket")
        self.geometry("400x300")
        
        if not os.path.exists(INSTALL_DIR):
            os.makedirs(INSTALL_DIR, exist_ok=True)

        tk.Label(self, text="URL приложения (.zip, .tar.gz, .tar.xz):").pack(pady=10)
        self.url_entry = tk.Entry(self, width=50)
        self.url_entry.pack(pady=5)
        self.url_entry.insert(0, "https://example.com/app.tar.gz")

        self.install_btn = tk.Button(self, text="Скачать и Установить", command=self.start_install)
        self.install_btn.pack(pady=20)

        self.progress = ttk.Progressbar(self, orient=tk.HORIZONTAL, length=300, mode='indeterminate')
        self.progress.pack(pady=10)
        
        self.status_lbl = tk.Label(self, text="Готов к работе")
        self.status_lbl.pack()

    def start_install(self):
        url = self.url_entry.get()
        if not url:
            messagebox.showerror("Ошибка", "Введите URL!")
            return
        
        self.progress.start()
        self.install_btn.config(state=tk.DISABLED)
        self.status_lbl.config(text="Скачивание...")
        
        # Запускаем в отдельном потоке, чтобы GUI не зависал
        threading.Thread(target=self.download_and_install, args=(url,), daemon=True).start()

    def download_and_install(self, url):
        filename = url.split('/')[-1]
        filepath = os.path.join("/tmp", filename)
        
        try:
            # Скачивание
            urllib.request.urlretrieve(url, filepath)
            self.status_lbl.config(text="Распаковка...")
            
            # Распаковка
            if filename.endswith(".zip"):
                with zipfile.ZipFile(filepath, 'r') as zip_ref:
                    zip_ref.extractall(INSTALL_DIR)
            elif filename.endswith(('.tar.gz', '.tgz', '.tar.xz', '.tar')):
                with tarfile.open(filepath, 'r:*') as tar_ref:
                    tar_ref.extractall(INSTALL_DIR)
            else:
                raise ValueError("Неподдерживаемый формат архива")

            os.remove(filepath)
            self.after(0, self.on_success)
        except Exception as e:
            self.after(0, lambda: self.on_error(str(e)))

    def on_success(self):
        self.progress.stop()
        self.install_btn.config(state=tk.NORMAL)
        self.status_lbl.config(text="Успешно установлено в /opt/apps")
        messagebox.showinfo("Успех", "Приложение установлено!")

    def on_error(self, err):
        self.progress.stop()
        self.install_btn.config(state=tk.NORMAL)
        self.status_lbl.config(text="Ошибка установки")
        messagebox.showerror("Ошибка", f"Не удалось установить:\n{err}")

if __name__ == "__main__":
    app = AppMarket()
    app.mainloop()