# Testing the Precision Farming Coprocessor

This directory contains two testing approaches:

## Option 1: Cocotb Testing (Recommended for TT08)

Uses Python-based Cocotb framework - this is the standard for Tiny Tapeout.

### Prerequisites
```bash
pip install cocotb cocotb-bus
```

### Run Tests
```bash
cd test
make
```

### Test Files
- `test.py` - Python testbench with 8 test cases
- `Makefile` - Build configuration for Cocotb

### Test Coverage
1. ✅ Reset behavior
2. ✅ Radish profile - temperature control
3. ✅ Basil profile - extra heating
4. ✅ Soil moisture watering
5. ✅ Override functionality
6. ✅ Heartbeat LED
7. ✅ Pea shoots - early cooling
8. ✅ All crop profiles

---

## Option 2: Traditional Verilog Testbench

Uses Icarus Verilog (iverilog) - simpler, no Python needed.

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt-get install iverilog gtkwave

# macOS
brew install icarus-verilog gtkwave
```

### Run Simulation
```bash
cd test

# Compile and simulate
iverilog -o sim tb_coprocessor.v ../src/project.v
vvp sim

# View waveforms
gtkwave tb_coprocessor.vcd
```

### Test Files
- `tb_coprocessor.v` - Traditional Verilog testbench

### Test Cases
1. ✅ Radish - temperature too cold → heater ON
2. ✅ Basil - temperature cool → heater ON (extra heat)
3. ✅ Soil dry → water pump ON
4. ✅ Dark environment → lights ON
5. ✅ Override mode → all actuators OFF
6. ✅ Pea shoots - optimal temp → cooler ON (early cool)
7. ✅ Sunflower - optimal humidity → dehumidifier ON
8. ✅ All optimal → minimal actuation
9. ✅ Heartbeat LED verification

---

## Expected Output

### Cocotb Output
```
     1.00ns INFO     cocotb.regression                  running test_reset (1/8)
                                                         Testing reset behavior
    50.00ns INFO     cocotb.regression                  ✓ Reset test passed
    50.00ns INFO     cocotb.regression                  test_reset passed
```

### Verilog Testbench Output
```
========================================
Precision Farming Coprocessor Testbench
========================================

[100] Applying reset...
[200] Reset released

[200] TEST 1: Radish profile - Temperature too cold
  ✓ PASS: Heater activated (uo_out[1] = 1)

[400] TEST 2: Basil profile - Needs extra heating
  ✓ PASS: Basil heater activated even at 'cool' (uo_out[1] = 1)
...
```

---

## Viewing Waveforms

### In GTKWave
1. Open `tb_coprocessor.vcd`
2. Add signals from the hierarchy:
   - `tb_coprocessor.dut.sensor_temperature`
   - `tb_coprocessor.dut.sensor_humidity`
   - `tb_coprocessor.dut.ctrl_heater`
   - `tb_coprocessor.dut.ctrl_cooler`
   - `tb_coprocessor.dut.ctrl_water_pump`
   - etc.
3. Zoom to see signal changes

### Key Signals to Watch
- **Inputs**: `ui_in[7:0]` (sensors), `uio_in[2:1]` (crop select)
- **Outputs**: `uo_out[6:0]` (actuators)
- **Internal**: `crop_select`, threshold values, status flags

---

## Debugging Tips

### Common Issues

**Issue**: "command not found: iverilog"
- **Solution**: Install Icarus Verilog (see prerequisites)

**Issue**: "ModuleNotFoundError: No module named 'cocotb'"
- **Solution**: `pip install cocotb cocotb-bus`

**Issue**: "No such file or directory: project.v"
- **Solution**: Run from the `test/` directory: `cd test && make`

**Issue**: Simulation runs but tests fail
- Check sensor encoding (0=low, 2=optimal, 3=high)
- Verify crop_select pins (uio[2:1])
- Check override is OFF (uio[0] = 0)

### Manual Signal Injection

Edit `tb_coprocessor.v` to test custom scenarios:
```verilog
// Custom test: All sensors at extremes
ui_in[1:0] = 2'b11;   // Temperature = 3 (too hot)
ui_in[3:2] = 2'b11;   // Humidity = 3 (too humid)
ui_in[5:4] = 2'b00;   // Light = 0 (dark)
ui_in[7:6] = 2'b00;   // Soil = 0 (dry)
```

---

## CI/CD Integration

For automated testing in GitHub Actions, add to `.github/workflows/test.yml`:

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y iverilog
          pip install cocotb cocotb-bus
      - name: Run tests
        run: |
          cd test
          make
```

---

## Next Steps

After verifying tests pass:
1. Review waveforms to understand behavior
2. Add more test cases if needed
3. Proceed with Tiny Tapeout submission
4. Synthesize with OpenLane

---

## Questions?

Open an issue on GitHub or check the main README.md
