# SaliSense: Automated Salinity Monitoring and Controlled Balancing System

SaliSense is a real-time salinity monitoring and automated balancing system designed for enclosed fishponds. It aims to modernize the aquaculture industry by replacing manual, labor-intensive water exchange practices with continuous sensing and automated corrections.

## What the System Does

The system consists of a hardware component (ESP32) that continuously monitors the salinity of the fishpond water and automatically triggers water pumps to correct salinity levels when they fall out of the target range. 

The SaliSense mobile application provides a real-time, read-only dashboard that allows users to:
- **View Real-Time Salinity:** Monitor current salinity levels remotely.
- **View System Status:** Check the active preset (e.g., Tilapia grow-out) and its target salinity range.
- **View Salinity Logs:** Access a timestamped history of salinity readings.
- **Receive Alerts:** Get instant notifications for sensor faults, pump failures, low reservoir levels, and overcorrection events.

*(Note: The app is strictly for monitoring; all control logic is handled autonomously by the ESP32 to ensure failsafe operation.)*

## Who Uses It

SaliSense is built for **small to medium-scale fishpond operators and aquaculture farmers** in the Philippines. It empowers them to shift from reactive monitoring to a proactive, automated approach, ensuring optimal water conditions for fish growth (such as Tilapia) without needing to be physically present at the tank.

## My Role

I am **Gervyn Clyde S. San Diego**, one of the core developers and researchers for this Capstone project (BSIT, Bulacan State University). My role encompasses developing the system's software architecture, building the mobile application, and ensuring reliable data integration between the hardware sensors and the cloud database.

## Tools and Languages Used

### Mobile Application (Frontend)
- **Flutter & Dart:** Cross-platform framework and language used to build the Android/iOS application.

### Backend & Cloud Services
- **Firebase Realtime Database:** For syncing live sensor data and system status.
- **Firebase Authentication:** For secure app access.

### Hardware (IoT)
- **ESP32 Microcontroller:** The brain of the hardware system handling sensor reads and pump automation.
- **C++ (Arduino Framework):** Used to program the ESP32.
- **PlatformIO & Wokwi:** For hardware development, testing, and simulation.
