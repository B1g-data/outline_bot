import json
import threading
from outline_vpn.outline_vpn import OutlineVPN
from .config import OUTLINE_API_URL, CERT_SHA256

# Инициализация клиента OutlineAPI
outline_client = OutlineVPN(OUTLINE_API_URL, CERT_SHA256)

class KeyUpdater:
    def __init__(self):
        self.keys = []
        self.update_triggered = False
        self.timer_event = threading.Event()  # Используем событие для сброса таймера

    def update_keys(self):
        """Функция для обновления ключей и сохранения их в файл keys.json"""
        try:
            # Получаем новые ключи
            new_keys = outline_client.get_keys()

            # Преобразуем ключи в сериализуемый формат
            serializable_keys = [
                key.to_dict() if hasattr(key, 'to_dict') else key.__dict__ for key in new_keys
            ]

            # Если ключи обновились, сбрасываем таймер
            if self.keys != serializable_keys:
                self.keys = serializable_keys
                with open("keys.json", "w", encoding="utf-8") as file:
                    json.dump(self.keys, file, ensure_ascii=False, indent=4)
                print("Ключи обновлены и сохранены в keys.json")
        except Exception as e:
            print(f"Ошибка при обновлении ключей: {e}")

    def force_update(self):
        """Принудительное обновление ключей и сброс таймера"""
        self.update_triggered = True
        self.timer_event.set()  # Устанавливаем событие, чтобы сбросить таймер

    def schedule_key_updates(self, interval=1200):
        """Функция, которая обновляет ключи каждые 1200 секунд с учетом сброса таймера"""
        def run():
            self.update_keys()  # Выполняем первое обновление сразу при запуске
            while True:
                # Ждем до события или истечения интервала 
                event_triggered = self.timer_event.wait(timeout=interval)

                if event_triggered:
                    self.timer_event.clear()  # Сбрасываем событие для следующего цикла

                # Выполняем обновление ключей
                self.update_keys()

                # Сбрасываем флаг, если было принудительное обновление
                if self.update_triggered:
                    self.update_triggered = False

        thread = threading.Thread(target=run, daemon=True)
        thread.start()