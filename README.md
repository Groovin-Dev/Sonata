# Sonata

A macOS music player for HypeM built with SwiftUI and Liquid Glass styling.

> **Note:** This project is in active development. Every commit could introduce breaking changes.

## Features

- Browse popular, latest, and remixed tracks
- View your favorites, history, and feed
- Explore music blogs and playlists
- Shuffle and repeat playback modes
- Keyboard shortcuts for playback control

## Requirements

- macOS 15.0+
- Xcode 16+
- HypeM account

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Groovin-Dev/Sonata.git
   cd Sonata
   ```

2. Set environment variables for the HypeM API:
   ```bash
   export HYPEM_API_KEY="your_api_key"
   export HYPEM_USERNAME="your_username"
   export HYPEM_PASSWORD="your_password"
   ```

3. Open in Xcode:
   ```bash
   open Sonata.xcodeproj
   ```

4. Build and run (Cmd+R)

## Usage

### Navigation

Use the sidebar to switch between sections:
- **Discover** - Popular and trending tracks
- **Favorites** - Your liked tracks
- **History** - Recently played
- **Feed** - Updates from blogs you follow
- **Playlists** - Your saved playlists
- **Blogs** - Browse music blogs

### Playback Controls

- **Space** - Play/Pause
- **Cmd+Right** - Next track
- **Cmd+Left** - Previous track
- **Cmd+R** - Refresh current view

The player bar at the bottom shows the current track with transport controls, shuffle/repeat toggles, and volume.

## Tools

The `Tools/` directory contains utilities for API development:

- **AuthProbe.swift** - Swift CLI for testing HypeM authentication
- **api_probe.py** - Python script for exploring API endpoints

Run the Python probe:
```bash
export HYPEM_USERNAME="your_username"
export HYPEM_PASSWORD="your_password"
export HYPEM_API_KEY="your_api_key"
python Tools/api_probe.py
```
