Precision Farming Coprocessor - Tiny Tapeout 08

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Tiny Tapeout](https://img.shields.io/badge/Tiny%20Tapeout-08-orange)
![Language](https://img.shields.io/badge/language-Verilog-green)

An autonomous environmental control coprocessor for microgreens and precision agriculture, designed for Tiny Tapeout 08.

🌱 Overview

This hardware coprocessor continuously monitors environmental sensors and directly controls actuators to maintain optimal growing conditions for various crops—all without software intervention. It's designed for low-latency, predictable, and autonomous operation.

Key Features

✅ **4 Environmental Sensors** (2-bit each): Temperature, Humidity, Light, Soil Moisture  
✅ **5 Actuator Controls**: Water pump, Heater, Cooler, Lights, Dehumidifier  
✅ **4 Crop Profiles**: Radish, Basil, Pea Shoots, Sunflower (hardware-selectable)  
✅ **Autonomous Operation**: Real-time control without CPU intervention  
✅ **Override Capability**: Main processor can pause control for maintenance  
✅ **Fault Detection**: Monitors for contradictory states  
✅ **Low Latency**: Single-cycle sensor-to-actuator response  
✅ **Tiny Tapeout Compatible**: 1×2 tile, SKY130 process  

📐 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  External Sensors                       │
│        (Temperature, Humidity, Light, Soil)             │
└───────────────────┬─────────────────────────────────────┘
                    │ 2-bit digital values (0-3)
                    ▼
┌─────────────────────────────────────────────────────────┐
│          Precision Farming Coprocessor (ASIC)           │
│  ┌───────────────────────────────────────────────────┐  │
│  │   Crop Profile Selector (2 pins)                  │  │
│  │   ├─ 00: Radish      ├─ 10: Pea Shoots           │  │
│  │   ├─ 01: Basil       └─ 11: Sunflower            │  │
│  └────────────────┬──────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────▼──────────────────────────────────┐  │
│  │       Threshold Comparison Logic                  │  │
│  │  (Compares sensors vs crop-specific thresholds)  │  │
│  └────────────────┬──────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────▼──────────────────────────────────┐  │
│  │        Actuator Control Logic                     │  │
│  │  (Drives outputs based on sensor assessment)      │  │
│  └────────────────┬──────────────────────────────────┘  │
└───────────────────┼──────────────────────────────────────┘
                    │ Digital control signals
                    ▼
┌─────────────────────────────────────────────────────────┐
│             Power Drivers (External)                    │
│       (Relays, MOSFETs, Solid-State Relays)             │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│                   Actuators                             │
│  Water Pump │ Heater │ Cooler │ Lights │ Dehumidifier   │
└─────────────────────────────────────────────────────────┘
```
📊 Sensor Encoding

All sensors use **2-bit encoding** for 4-level precision:

| Value | Binary | Temperature | Humidity | Light | Soil Moisture |
|-------|--------|-------------|----------|-------|---------------|
| 0 | `00` | Too Cold | Too Dry | Dark | Dry |
| 1 | `01` | Cool | Low | Low Light | Slightly Dry |
| 2 | `10` | **Optimal** | **Optimal** | **Optimal** | **Optimal** |
| 3 | `11` | Too Hot | Too Humid | Too Bright | Saturated |

🌾 Crop Profiles

Select your crop using pins `uio[2:1]`:

Profile 0: Radish (`00`)
- **Temperature**: Balanced (heat at 0, cool at 3)
- **Humidity**: Moderate tolerance
- **Light**: High requirement
- **Water**: Moderate (water at level 1)

Profile 1: Basil (`01`)
- **Temperature**: Warm-loving (heat at 0-1, cool at 3)
- **Humidity**: Higher tolerance
- **Light**: Very high (lights at 0-1)
- **Water**: High (water at 0-1)

Profile 2: Pea Shoots (`10`)
- **Temperature**: Cool preference (cool at 2-3)
- **Humidity**: Moderate
- **Light**: Medium requirement
- **Water**: High (water at 0-1)

Profile 3: Sunflower (`11`)
- **Temperature**: Moderate
- **Humidity**: Lower tolerance (dehumidify at 2-3)
- **Light**: High requirement
- **Water**: Moderate

📌 Pin Mapping

 Dedicated Inputs (`ui_in[7:0]`)
| Pin | Signal | Description |
|-----|--------|-------------|
| 0-1 | sensor_temperature | Temperature (2-bit) |
| 2-3 | sensor_humidity | Humidity (2-bit) |
| 4-5 | sensor_light | Light intensity (2-bit) |
| 6-7 | sensor_soil_moisture | Soil moisture (2-bit) |

Dedicated Outputs (`uo_out[7:0]`)
| Pin | Signal | Description |
|-----|--------|-------------|
| 0 | ctrl_water_pump | Water pump control |
| 1 | ctrl_heater | Heater control |
| 2 | ctrl_cooler | Cooling/ventilation |
| 3 | ctrl_light | Artificial lights |
| 4 | flag_fault | Fault alert |
| 5 | status_heartbeat | Heartbeat LED (~1Hz) |
| 6 | ctrl_dehumidifier | Dehumidifier |
| 7 | (reserved) | Future expansion |

Bidirectional (`uio[7:0]`)
| Pin | Direction | Signal | Description |
|-----|-----------|--------|-------------|
| 0 | Input | cmd_override | Override/pause mode |
| 1-2 | Input | crop_select | Crop profile selector |
| 3 | Input | uart_rx | UART RX (future) |
| 7 | Output | uart_tx | UART TX |

🚀 Getting Started

 Prerequisites
- Icarus Verilog or Verilator
- Python 3.8+ with cocotb
- GTKWave (for waveform viewing)

Clone and Test
```bash
Clone the repository
git clone https://github.com/SoorajSajeev/Precision-farming-coprocessor.git
cd Precision-farming-coprocessor

Run tests (requires cocotb)
cd test
make

View waveforms
gtkwave tb.vcd
```

File Structure
```
Precision-farming-coprocessor/
├── src/
│   └── project.v              # Main Verilog source
├── test/
│   └── test.py                # Cocotb testbench
├── docs/
│   └── info.md                # Detailed documentation
├── info.yaml                  # Tiny Tapeout metadata
└── README.md                  # This file
```

🧪 Testing

The project includes comprehensive Cocotb tests:

- ✅ Reset behavior
- ✅ Temperature control (all profiles)
- ✅ Soil moisture watering
- ✅ Override functionality
- ✅ Crop profile switching
- ✅ Heartbeat generation
- ✅ Fault detection

Run tests:
```bash
cd test
make
```

📝 Usage Example

Arduino Integration
```cpp
// Pin definitions
const int CROP_BIT0 = 5;  // uio[1]
const int CROP_BIT1 = 6;  // uio[2]
const int OVERRIDE = 7;   // uio[0]

enum Crop { RADISH=0, BASIL=1, PEA=2, SUNFLOWER=3 };

void setup() {
  pinMode(CROP_BIT0, OUTPUT);
  pinMode(CROP_BIT1, OUTPUT);
  pinMode(OVERRIDE, OUTPUT);
  
  // Select Basil profile
  selectCrop(BASIL);
  
  // Enable autonomous mode
  digitalWrite(OVERRIDE, LOW);
}

void selectCrop(Crop crop) {
  digitalWrite(CROP_BIT0, crop & 1);
  digitalWrite(CROP_BIT1, (crop >> 1) & 1);
}
```
🔮 Future Enhancements

- [ ] UART reporting of sensor values and fault codes
- [ ] Configurable thresholds via serial interface
- [ ] Time-based scheduling (day/night cycles)
- [ ] Data logging capabilities
- [ ] More crop profiles
- [ ] Integration with IoT platforms

📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
 👤 Author

**SoorajSajeev**
- GitHub: [@SoorajSajeev](https://github.com/SoorajSajeev)

🙏 Acknowledgments

- Built for [Tiny Tapeout 08](https://tinytapeout.com)
- Uses the open-source [SKY130 PDK](https://github.com/google/skywater-pdk)
- Inspired by precision agriculture and sustainable farming

 📚 Documentation

For detailed documentation, see:
- [docs/info.md](docs/info.md) - Complete project documentation
- [info.yaml](info.yaml) - Tiny Tapeout configuration

---

**Status**: Ready for Tiny Tapeout 08 submission 🎉

Star ⭐ this repo if you find it useful!
