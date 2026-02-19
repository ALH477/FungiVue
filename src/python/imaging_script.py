#!/usr/bin/env python3
"""
FungiVue Ultrasound Imaging Script
Reads sensor data from Arduino and generates A-scan images for mushroom growth monitoring.
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

try:
    import serial
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)

try:
    import numpy as np
except ImportError:
    print("ERROR: numpy not installed. Run: pip install numpy")
    sys.exit(1)

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
except ImportError:
    print("ERROR: matplotlib not installed. Run: pip install matplotlib")
    sys.exit(1)


class FungiVueImaging:
    def __init__(
        self,
        serial_port: str = "/dev/ttyUSB0",
        baud_rate: int = 9600,
        scan_directory: str = "/var/www/scans",
        model_path: Optional[str] = None
    ):
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.scan_directory = Path(scan_directory)
        self.model_path = model_path
        self.scan_count = 0
        self.serial_conn: Optional[serial.Serial] = None

        self.scan_directory.mkdir(parents=True, exist_ok=True)

    def connect(self) -> bool:
        """Establish serial connection to Arduino."""
        try:
            self.serial_conn = serial.Serial(
                self.serial_port,
                self.baud_rate,
                timeout=1
            )
            time.sleep(2)
            print(f"Connected to Arduino on {self.serial_port}")
            return True
        except serial.SerialException as e:
            print(f"ERROR: Could not connect to {self.serial_port}: {e}")
            return False

    def read_sensor_data(self) -> dict:
        """Read and parse sensor data from Arduino."""
        if not self.serial_conn:
            return {}

        try:
            line = self.serial_conn.readline().decode('utf-8').strip()
            if not line:
                return {}

            parts = line.split(',')
            data = {}

            for part in parts:
                if ':' in part:
                    key, value = part.split(':', 1)
                    try:
                        data[key.strip()] = float(value.strip())
                    except ValueError:
                        data[key.strip()] = value.strip()

            return data

        except (serial.SerialException, UnicodeDecodeError) as e:
            print(f"Error reading sensor data: {e}")
            return {}

    def generate_ascan_plot(self, distance: float, temperature: float = 25.0, humidity: float = 60.0) -> Path:
        """Generate A-scan visualization plot."""
        time_axis = np.linspace(0, 100, 500)
        amplitude = np.zeros_like(time_axis)

        peak_position = int((distance / 100.0) * len(time_axis))
        if 0 < peak_position < len(time_axis):
            amplitude[peak_position] = 1.0
            for i in range(max(0, peak_position - 20), min(len(time_axis), peak_position + 20)):
                amplitude[i] = np.exp(-((i - peak_position) ** 2) / 50)

        noise_level = 0.05
        amplitude += np.random.normal(0, noise_level, len(amplitude))
        amplitude = np.clip(amplitude, 0, 1)

        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), gridspec_kw={'height_ratios': [2, 1]})

        ax1.fill_between(time_axis, amplitude, alpha=0.6, color='#3498db')
        ax1.plot(time_axis, amplitude, color='#2980b9', linewidth=1.5)
        ax1.axvline(x=time_axis[peak_position] if peak_position > 0 else 0, 
                    color='#e74c3c', linestyle='--', alpha=0.7, label=f'Peak: {distance:.1f}mm')
        ax1.set_xlim(0, 100)
        ax1.set_ylim(0, 1.2)
        ax1.set_xlabel('Time (μs)')
        ax1.set_ylabel('Amplitude')
        ax1.set_title('FungiVue A-Scan: Mushroom Growth Detection')
        ax1.legend()
        ax1.grid(True, alpha=0.3)

        env_data = [f"Temperature: {temperature}°C", f"Humidity: {humidity}%", f"Distance: {distance}mm"]
        ax2.text(0.5, 0.5, '\n'.join(env_data), 
                 transform=ax2.transAxes, fontsize=14, verticalalignment='center',
                 horizontalalignment='center', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
        ax2.axis('off')

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"scan_{timestamp}.png"
        filepath = self.scan_directory / filename

        plt.savefig(filepath, dpi=100, bbox_inches='tight')
        plt.close()

        return filepath

    def update_scans_json(self, scan_file: Path):
        """Update scans.json with new scan entry."""
        scans_file = self.scan_directory / "scans.json"

        if scans_file.exists():
            with open(scans_file, 'r') as f:
                try:
                    scans = json.load(f)
                except json.JSONDecodeError:
                    scans = []
        else:
            scans = []

        entry = {
            "url": f"/scans/{scan_file.name}",
            "name": f"Scan {self.scan_count:04d}",
            "timestamp": datetime.now().isoformat()
        }

        scans.insert(0, entry)

        with open(scans_file, 'w') as f:
            json.dump(scans, f, indent=2)

    def run(self, interval: int = 60):
        """Main imaging loop."""
        if not self.connect():
            print("Failed to connect to Arduino. Exiting.")
            sys.exit(1)

        print(f"FungiVue Imaging System started")
        print(f"Scan interval: {interval} seconds")
        print(f"Scan directory: {self.scan_directory}")
        print("Press Ctrl+C to stop")

        try:
            while True:
                data = self.read_sensor_data()

                if data:
                    distance = data.get('distance', 0)
                    temperature = data.get('temperature', 25.0)
                    humidity = data.get('humidity', 60.0)

                    if distance > 0:
                        scan_file = self.generate_ascan_plot(distance, temperature, humidity)
                        self.update_scans_json(scan_file)
                        self.scan_count += 1
                        print(f"Scan saved: {scan_file.name} (Distance: {distance}mm)")
                    else:
                        print(f"Invalid reading: {data}")
                else:
                    print("Waiting for sensor data...")

                time.sleep(interval)

        except KeyboardInterrupt:
            print("\nShutting down FungiVue imaging system...")
        finally:
            if self.serial_conn:
                self.serial_conn.close()


def main():
    parser = argparse.ArgumentParser(description='FungiVue Ultrasound Imaging System')
    parser.add_argument('-p', '--port', default='/dev/ttyUSB0', help='Arduino serial port')
    parser.add_argument('-b', '--baud', type=int, default=9600, help='Baud rate')
    parser.add_argument('-o', '--output', default='/var/www/scans', help='Output directory for scans')
    parser.add_argument('-m', '--model', help='Path to TensorFlow Lite model')
    parser.add_argument('-i', '--interval', type=int, default=60, help='Scan interval in seconds')

    args = parser.parse_args()

    imaging = FungiVueImaging(
        serial_port=args.port,
        baud_rate=args.baud,
        scan_directory=args.output,
        model_path=args.model
    )

    imaging.run(interval=args.interval)


if __name__ == "__main__":
    main()
