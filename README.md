# dijkstra_runner

# Dijkstra Runner 🏃‍♂️🗺️

> **The engine behind the shortest path.**

A Flutter application that demonstrates how navigation systems (like Google Maps) calculate the most efficient route between two points using **Dijkstra's Algorithm**.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Algorithms](https://img.shields.io/badge/Algorithms-Pathfinding-green?style=for-the-badge)

---

## 📺 As Seen on YouTube

This repository contains the source code discussed in my video:
**[(6) What Google Maps uses underneath the hood, and how it relates to pathfinding](YOUR_YOUTUBE_LINK_HERE)**

[![Watch the Video](https://img.youtube.com/vi/YOUR_VIDEO_ID/maxresdefault.jpg)](YOUR_YOUTUBE_LINK_HERE)

*Click the image above to watch the breakdown!*

---

## 📖 About The Project

Have you ever wondered how your phone knows exactly which turn to take to save you 2 minutes in traffic? It comes down to **Graph Theory**.

This project implements **Dijkstra's Algorithm**, the gold standard for finding the shortest path in a weighted graph. It visualizes the process of visiting nodes, relaxing edges, and back-tracing the optimal route.

### Features
* **Graph Construction:** visualization of Nodes (locations) and Edges (roads).
* **Weighted Paths:** Simulates distance/cost between points.
* **Visual Pathfinding:** See the shortest path drawn on the screen.
* **Clean Architecture:** Built using scalable Flutter best practices.

---

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev/)
* **Language:** Dart
* **Core Logic:** Dijkstra's Algorithm (Priority Queue implementation)

---

## 🚀 Getting Started

Follow these steps to run the pathfinder locally.

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) installed on your machine.
* An Android Emulator, iOS Simulator, or physical device.

### Installation

1.  **Clone the repo**
    ```sh
    git clone [https://github.com/YOUR_USERNAME/dijkstra_runner.git](https://github.com/YOUR_USERNAME/dijkstra_runner.git)
    ```
2.  **Install packages**
    ```sh
    cd dijkstra_runner
    flutter pub get
    ```
3.  **Run the app**
    ```sh
    flutter run
    ```

---

## 🧠 How It Works (The Code)

The core logic resides in `lib/algorithms/dijkstra.dart` (adjust path as needed).

1.  **Initialization:** We set all distances to `Infinity` and the start node to `0`.
2.  **Priority Queue:** We use a min-priority queue to always explore the closest unvisited node next.
3.  **Relaxation:** For every neighbor of the current node, we calculate if the new path is shorter than the old one. If it is, we update the distance and the "parent" pointer.
4.  **Backtracking:** Once we hit the target, we retrace the parent pointers to build the final route.

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

## 📧 Contact

**Emmanuel Onyeji** - [LinkedIn Profile](LINKEDIN_URL)

Project Link: [https://github.com/YOUR_USERNAME/dijkstra_runner](https://github.com/YOUR_USERNAME/dijkstra_runner)

---

*Enjoying the code? Don't forget to give the repo a star! ⭐*
