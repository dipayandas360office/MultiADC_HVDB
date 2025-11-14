import sys
import threading
import time
import socket
import serial
import numpy as np
from serial.tools import list_ports
from PyQt5.QtWidgets import QApplication, QMainWindow
from PyQt5.QtCore import QTimer
from HVDV import Ui_Control

# Curve fitting constants for GAS FLOW
A = 92.71
B = 0.007144
C = 657.5

# Ethernet connection parameters (edit as needed)
ETH_IP = '120.168.1.200'
ETH_PORT = 200


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.ui = Ui_Control()
        self.ui.setupUi(self)

        # ---- Choose one source only: update here or via the UI ----
        self.use_ethernet = False  # Set True to use Ethernet, False for serial

        self.ser = None
        self.eth_socket = None
        self.connection = None  
        self.rx_thread = None

        if self.use_ethernet:
            try:
                self.eth_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.eth_socket.connect((ETH_IP, ETH_PORT))
                self.connection = self.eth_socket
                print("Ethernet connected to server.")
                self.rx_thread = threading.Thread(target=self.run_rx, args=(self.eth_socket,), daemon=True)
                self.rx_thread.start()
            except Exception as e:
                print(f"Ethernet connection failed: {e}")
        else:
            def find_arty7_port():
                ports = list_ports.comports()
                for port in ports:
                    if "Digilent" in port.description or "Arty" in port.description:
                        return port.device
                return None

            SERIAL_PORT = find_arty7_port()
            if SERIAL_PORT:
                self.ser = serial.Serial(SERIAL_PORT, baudrate=921600, timeout=0.01)
                self.connection = self.ser
                print(f"Connected TX on {SERIAL_PORT}")
                self.rx_thread = threading.Thread(target=self.run_rx, args=(self.ser,), daemon=True)
                self.rx_thread.start()
            else:
                print("No Arty7 FPGA serial device found.")

        # Button actions
        self.ui.pushButton_START.clicked.connect(self.start_clicked)
        self.ui.pushButton_STOP.clicked.connect(self.stop_clicked)
        self.ui.pushButton_RESET.clicked.connect(self.reset_clicked)

        # Connect pushButton_a01 ... pushButton_a24
        for i in range(1, 25):
            btn_name = f"pushButton_a{i:02d}"
            btn = getattr(self.ui, btn_name, None)
            if btn:
                btn.clicked.connect(lambda _, n=i: self.send_data(f"a{n:02d}t"))
                btn.setStyleSheet(
                    "border: 1px solid black; background-color: lightgray; color: black;"
                )

        # Connect pushButton_ALLON
        all_on_btn = getattr(self.ui, "pushButton_ALLON", None)
        if all_on_btn:
            all_on_btn.clicked.connect(self.send_allon_commands)
            all_on_btn.setStyleSheet(
                "border: 1px solid black; background-color: lightblue; color: black;"
            )

        # Connect pushButton_ALLOFF
        all_off_btn = getattr(self.ui, "pushButton_ALLOFF", None)
        if all_off_btn:
            all_off_btn.clicked.connect(self.send_alloff_commands)
            all_off_btn.setStyleSheet(
                "border: 1px solid black; background-color: pink; color: black;"
            )

    # ----------- Unified RX thread for USB or Ethernet ---------
    def run_rx(self, connection):
        buffer = bytearray()
        while connection:
            try:
                if self.use_ethernet:
                    data = connection.recv(1024)
                    if not data:
                        print("Ethernet: Connection closed by server.")
                        break
                else:
                    data = connection.read(connection.in_waiting or 1)
                if data:
                    buffer.extend(data)
                    while len(buffer) >= 11:
                        if buffer[0] == 0xF8:
                            packet = buffer[:11]
                            del buffer[:11]
                            b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11 = packet
                            dataCount = b2
                            timeVal = (b3 << 16) | (b4 << 8) | b5
                            port_val = (b6 << 16) | (b7 << 8) | b8
                            data_val = (b9 << 8) | b10
                            # UI update logic
                            if b6 in (0x61, 0x62):  # 'a' or 'b'
                                ascii_char = chr(b6) + chr(b7) + chr(b8)
                                opto_state = b10
                                btn = getattr(self.ui, f"pushButton_{ascii_char}", None)
                                print(f"Received: {ascii_char} : {opto_state} ")
                                if btn:
                                    btn.setStyleSheet(
                                        "border: 1px solid black; background-color: green; color: white;"
                                        if opto_state
                                        else "border: 1px solid black; background-color: lightgray; color: black;"
                                    )
                            else:
                                self.update_display(port_val, data_val)
                        else:
                            del buffer[0]
                else:
                    time.sleep(0.001)
            except Exception as e:
                print("RX error:", e)
                time.sleep(0.01)

    # ---------------- TX ----------------
    def send_data(self, data: str):
        try:
            if self.use_ethernet and self.eth_socket:
                # Ethernet, with protocol markers if needed
                data_bytes = ("ff" + data + "ff").encode('utf-8')
                self.eth_socket.sendall(data_bytes)
                print(f"Sent: {data}")
            elif self.ser and self.ser.is_open:
                self.ser.write(data.encode())
                print(f"Sent: {data}")
        except Exception as e:
            print("Send error:", e)

    # ---------------- Send All ON Commands ----------------
    def send_allon_commands(self):
        def send_commands_thread():
            for i in range(1, 25):
                cmd = f'a{i:02d}1'
                self.send_data(cmd)
                time.sleep(0.15)  # 150 ms delay

        threading.Thread(target=send_commands_thread, daemon=True).start()

    # ---------------- Send All OFF Commands ----------------
    def send_alloff_commands(self):
        def send_commands_thread():
            for i in range(1, 25):
                cmd = f'a{i:02d}0'   # OFF commands assumed as b01..b24
                self.send_data(cmd)
                time.sleep(0.15)

        threading.Thread(target=send_commands_thread, daemon=True).start()

    # ---------------- Button Handlers ----------------
    def start_clicked(self):
        self.send_data("1")
        self.ui.pushButton_START.setStyleSheet(
            "border: 3px solid red;background-color: green; color: white; width: 200px;"
        )
        self.ui.pushButton_STOP.setStyleSheet("border: 3px solid red;width: 200px;")
        self.ui.pushButton_RESET.setStyleSheet("border: 3px solid red;width: 200px;")

    def stop_clicked(self):
        self.send_data("2")
        self.ui.pushButton_STOP.setStyleSheet(
            "border: 3px solid red;background-color: red; color: white; width: 200px;"
        )
        self.ui.pushButton_START.setStyleSheet("border: 3px solid red;width: 200px;")
        self.ui.pushButton_RESET.setStyleSheet("border: 3px solid red;width: 200px;")

    def reset_clicked(self):
        self.send_data("3")
        self.ui.pushButton_RESET.setStyleSheet(
            "border: 3px solid red;background-color: red; color: white; width: 200px;"
        )
        self.ui.pushButton_START.setStyleSheet("border: 3px solid red;width: 200px;")
        self.ui.pushButton_STOP.setStyleSheet("border: 3px solid red;width: 200px;")
        QTimer.singleShot(
            200,
            lambda: self.ui.pushButton_RESET.setStyleSheet(
                "border: 3px solid red;width: 200px;"
            ),
        )

    # ---------------- Update Display ----------------
    def update_display(self, port, data):
        if port == 1114384:
            flow = A / (1.0 + np.exp(-B * (data - C)))
            self.ui.lcdNumber_G1.display(flow)
        elif port == 0:
            self.ui.lcdNumber_T11.display(data)
        elif port == 1:
            self.ui.lcdNumber_T21.display(data)
        elif port == 2:
            self.ui.lcdNumber_T31.display(data)
        elif port == 3:
            self.ui.lcdNumber_T41.display(data)
        elif port == 4:
            self.ui.lcdNumber_T12.display(data)
        elif port == 5:
            self.ui.lcdNumber_T22.display(data)
        elif port == 6:
            self.ui.lcdNumber_T32.display(data)
        elif port == 7:
            self.ui.lcdNumber_T42.display(data)
        elif port == 8:
            self.ui.lcdNumber_T13.display(data)
        elif port == 9:
            self.ui.lcdNumber_T23.display(data)
        elif port == 10:
            self.ui.lcdNumber_T33.display(data)
        elif port == 11:
            self.ui.lcdNumber_T43.display(data)
        elif port == 12:
            self.ui.lcdNumber_T14.display(data)
        elif port == 13:
            self.ui.lcdNumber_T24.display(data)
        elif port == 14:
            self.ui.lcdNumber_T34.display(data)
        elif port == 15:
            self.ui.lcdNumber_T44.display(data)
        else:
            print(f"Unknown port {port}, data={data}")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

