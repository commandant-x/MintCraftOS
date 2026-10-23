package io.github.commandantx.mintcraft.bridge;

import dan200.computercraft.api.ComputerCraftAPI;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.config.ModConfig;
import net.neoforged.fml.event.lifecycle.FMLCommonSetupEvent;

@Mod("mintcraft_vehicle_bridge")
public final class VehicleBridge {
    public VehicleBridge(IEventBus bus, ModContainer container) {
        container.registerConfig(ModConfig.Type.SERVER,TerrainPolicy.SPEC);
        bus.addListener(this::setup);
    }

    private void setup(FMLCommonSetupEvent event) {
        event.enqueueWork(() -> { ComputerCraftAPI.registerAPIFactory(VehicleApi::new); ComputerCraftAPI.registerAPIFactory(TerrainApi::new); });
    }
}
