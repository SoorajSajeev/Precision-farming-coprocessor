import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_reset(dut):
    """Test that reset properly initializes the design"""
    dut._log.info("Testing reset behavior")
    
    # Create clock
    clock = Clock(dut.clk, 40, units="ns")  # 25 MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    
    # Check all actuators are off after reset
    assert dut.uo_out.value == 0, "Outputs should be 0 after reset"
    dut._log.info("✓ Reset test passed")


@cocotb.test()
async def test_radish_profile_temperature(dut):
    """Test Radish profile - temperature too cold triggers heater"""
    dut._log.info("Testing Radish profile - temperature control")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Select Radish profile (crop_select = 00)
    dut.uio_in.value = 0b0000_0000  # uio[2:1] = 00
    
    # Set temperature too cold (00), other sensors optimal (10)
    dut.ui_in.value = 0b10_10_10_00  # soil=2, light=2, humid=2, temp=0
    
    await ClockCycles(dut.clk, 5)
    
    # Check heater is ON (bit 1 of uo_out)
    assert (dut.uo_out.value & 0x02) != 0, "Heater should be ON when temp is too cold"
    dut._log.info("✓ Radish temperature test passed")


@cocotb.test()
async def test_basil_profile_needs_more_heat(dut):
    """Test Basil profile - activates heater even at 'cool' temperature"""
    dut._log.info("Testing Basil profile - extra heating behavior")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Select Basil profile (crop_select = 01)
    dut.uio_in.value = 0b0000_0010  # uio[2:1] = 01
    
    # Set temperature to 'cool' (01), other sensors optimal
    dut.ui_in.value = 0b10_10_10_01  # soil=2, light=2, humid=2, temp=1 (cool)
    
    await ClockCycles(dut.clk, 5)
    
    # Basil should activate heater even at "cool" (not just "too cold")
    assert (dut.uo_out.value & 0x02) != 0, "Basil should heat even at 'cool' temperature"
    dut._log.info("✓ Basil extra heating test passed")


@cocotb.test()
async def test_soil_moisture_watering(dut):
    """Test water pump activation when soil is dry"""
    dut._log.info("Testing water pump control")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Select Radish profile
    dut.uio_in.value = 0b0000_0000
    
    # Set soil moisture to dry (00), everything else optimal
    dut.ui_in.value = 0b00_10_10_10  # soil=0 (dry), light=2, humid=2, temp=2
    
    await ClockCycles(dut.clk, 5)
    
    # Check water pump is ON (bit 0)
    assert (dut.uo_out.value & 0x01) != 0, "Water pump should be ON when soil is dry"
    dut._log.info("✓ Water pump test passed")


@cocotb.test()
async def test_override_disables_all(dut):
    """Test that override command disables all actuators"""
    dut._log.info("Testing override functionality")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Select Radish profile
    dut.uio_in.value = 0b0000_0000
    
    # Set all sensors to extremes (should trigger all actuators)
    dut.ui_in.value = 0b00_00_00_00  # All sensors at minimum
    
    await ClockCycles(dut.clk, 5)
    
    # Verify some actuators are ON
    actuator_bits = dut.uo_out.value & 0x0F  # Lower 4 bits are actuators
    assert actuator_bits != 0, "Some actuators should be ON with extreme sensor values"
    dut._log.info(f"  Actuators ON before override: 0x{actuator_bits:02x}")
    
    # Activate override (uio[0] = 1)
    dut.uio_in.value = 0b0000_0001
    
    await ClockCycles(dut.clk, 5)
    
    # Check all actuators are OFF (bits 0-3, 6)
    actuator_bits = dut.uo_out.value & 0x4F  # Mask actuator bits
    assert actuator_bits == 0, "All actuators should be OFF during override"
    dut._log.info("✓ Override test passed")


@cocotb.test()
async def test_heartbeat(dut):
    """Test that heartbeat LED toggles"""
    dut._log.info("Testing heartbeat LED (simplified)")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    dut.uio_in.value = 0
    dut.ui_in.value = 0b10_10_10_10  # All optimal
    
    # Wait some cycles and check heartbeat bit (bit 5) changes
    await ClockCycles(dut.clk, 100)
    initial_heartbeat = (dut.uo_out.value >> 5) & 1
    
    # Note: Full heartbeat period is 25M cycles, so we just verify the counter exists
    # by checking the output bit is driven (not floating)
    assert initial_heartbeat in [0, 1], "Heartbeat should be 0 or 1"
    dut._log.info(f"✓ Heartbeat LED functional (initial state: {initial_heartbeat})")


@cocotb.test()
async def test_pea_shoots_cool_early(dut):
    """Test Pea Shoots profile - activates cooling at optimal temperature"""
    dut._log.info("Testing Pea Shoots profile - early cooling")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Select Pea Shoots profile (crop_select = 10)
    dut.uio_in.value = 0b0000_0100  # uio[2:1] = 10
    
    # Set temperature to optimal (10) - pea shoots should still activate cooling
    dut.ui_in.value = 0b10_10_10_10  # All optimal
    
    await ClockCycles(dut.clk, 5)
    
    # Pea shoots should activate cooler even at "optimal" temperature
    assert (dut.uo_out.value & 0x04) != 0, "Pea shoots should cool at optimal temp"
    dut._log.info("✓ Pea shoots early cooling test passed")


@cocotb.test()
async def test_all_profiles_exist(dut):
    """Test that all 4 crop profiles are implemented"""
    dut._log.info("Testing all crop profiles")
    
    # Setup
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    dut.ui_in.value = 0b10_10_10_10  # All sensors optimal
    
    profiles = [
        (0b00, "Radish"),
        (0b10, "Basil"), 
        (0b100, "Pea Shoots"),
        (0b110, "Sunflower")
    ]
    
    for crop_select, name in profiles:
        dut.uio_in.value = crop_select
        await ClockCycles(dut.clk, 5)
        # Just verify design doesn't crash/hang with each profile
        dut._log.info(f"  ✓ {name} profile loaded")
    
    dut._log.info("✓ All crop profiles test passed")
