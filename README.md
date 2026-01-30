# Offline Bluetooth Chat App 📱💙

A robust, offline chat application built with **Flutter** that allows users to communicate without an internet connection using **Bluetooth Classic**.

This project demonstrates a hybrid implementation using **Dart** for the UI/Client logic and **Native Kotlin** for the secure Bluetooth Server (Host) implementation, ensuring compatibility and performance on modern Android devices.

## ✨ Key Features

*   **Offline Messaging:** Send and receive text messages instantly without Wi-Fi or Data.
*   **Dual Modes:**
    *   **Host (Server):** Creates a chat room and waits for incoming connections.
    *   **Client:** Scans for nearby devices and initiates connections.
*   **Smart Discovery:** Lists both currently scanned and previously **Bonded (Paired)** devices for reliable connections.
*   **Native Performance:** Uses a custom Kotlin implementation for the Bluetooth Server Socket to bypass standard library limitations.
*   **Modern UI:** Clean, dark-themed interface built with Material 3.

## 🛠️ Tech Stack

*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **Native Layer:** Kotlin (Android)
*   **Bluetooth Library:** `flutter_bluetooth_serial` (Client Side) & Android `BluetoothAdapter` (Server Side)
*   **State Management:** `flutter_bloc` / Native Streams
*   **Protocol:** Custom JSON-based message protocol over RFCOMM

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK installed (`flutter doctor`)
*   Android Device (Emulator support for Bluetooth is limited/non-existent)
*   Android SDK 21+ (Designed for Android 12/13 compatibility)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/offline-bluetooth-chat.git
    cd offline-bluetooth-chat
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    Connect your physical Android device and run:
    ```bash
    flutter run
    ```

## 📖 Usage Guide

### 1. Host Mode (Receiver)
1.  Tap **"Make Discoverable (Host)"** on the Home Screen.
2.  Allow the "Make Visible" permission prompt (300 seconds).
3.  The screen will show your **Device Name** and **Address**.
4.  Wait for a client to connect. Once connected, you will automatically be redirected to the Chat Screen.

### 2. Client Mode (Sender)
1.  Tap **"Find Devices (Client)"**.
2.  The app will list:
    *   **Paired Devices:** Previously connected devices (Recommended).
    *   **Available Devices:** Newly discovered nearby devices.
3.  Tap on the Host device's name to connect.

## 🔧 Troubleshooting

*   **"Device not found":**
    *   Ensure the Host device clicked "Make Discoverable" and accepted the system prompt.
    *   If discovery is flaky, go to **Android Settings > Bluetooth** on both phones and **Pair** them manually. They will then appear in the "Paired Devices" list in the app.
*   **"Permission Denied":**
    *   The app requires `Location`, `Bluetooth Connect`, and `Bluetooth Scan` permissions. Ensure all are granted in App Settings.

## 📂 Project Structure

*   `lib/core/bluetooth/`: Core logic for BluetoothService and Protocol.
*   `lib/features/`: UI Screens (Home, Discovery, Chat).
*   `android/app/src/main/kotlin/`: **Critical Native Code**. Contains `MainActivity.kt` which implements the RFCOMM Server Socket logic.

## 🤝 Contribution

Contributions are welcome! Please fork the repository and submit a pull request for any enhancements or bug fixes.

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
