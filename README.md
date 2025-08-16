# Windows 11 Post-Setup Wizard

This is a **GUI-driven configuration wizard** that installs applications, tweaks system settings, and optionally activates software — all in a single streamlined process after a fresh Windows setup.

> ⚠️ **Disclaimer:** Software is provided _“as-is”_, without warranty of any kind. Use at your own risk.


## 🖥️ Interactive UI

- Modern **WPF-based interface** (XAML layout).
    
- Supports **English (en)**, **Polish (pl)**, and **German (de)**.
    
- Configurable checkboxes for all main features:
    
    - Disable Bing in search
        
    - Disable hibernation
        
    - Disable activity history
        
    - Disable/remove OneDrive
        
    - Install Office, PowerToys, SumatraPDF, WinRAR, Chrome, Firefox
        
    - Activate Windows, Office, WinRAR
        
    - Clean up wizard files after completion
        

## ⚙️ Automated System Configuration

- Runs selected actions based on user selection in the UI.
    
- Applies registry tweaks, system policy changes, and software installs silently.
    
- Optional **Polish keyboard enforcement** (`en-US UI + pl-PL layout`).
    

## 🧩 Extensible Architecture

- Uses **modular PowerShell functions** (`modules/*.psm1`).
    
- Installers & activators loaded from **config.jsonc** and their respective folders.
    
- Office installation supports multiple modes (`no-outlook`, `no-onedrive`, etc.)