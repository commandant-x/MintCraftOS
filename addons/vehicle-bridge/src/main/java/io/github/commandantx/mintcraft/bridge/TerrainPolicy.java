package io.github.commandantx.mintcraft.bridge;
import java.util.List;
import net.neoforged.neoforge.common.ModConfigSpec;
/** Server-owner opt-in, independent of OS app permissions. */
final class TerrainPolicy {
    static final ModConfigSpec.BooleanValue ENABLED;
    static final ModConfigSpec.ConfigValue<List<? extends Integer>> COMPUTERS;
    static final ModConfigSpec SPEC;
    static {
        var b=new ModConfigSpec.Builder();
        ENABLED=b.comment("Read already-loaded local world blocks for explicitly allowed ComputerCraft IDs.").define("terrainReadsEnabled",false);
        COMPUTERS=b.comment("Allowed computer IDs. Empty denies all.").defineListAllowEmpty("terrainComputerIds",List.<Integer>of(),v->v instanceof Integer id && id>=0);
        SPEC=b.build();
    }
    static boolean allowed(int id) { return TerrainSelection.allowed(ENABLED.get(),COMPUTERS.get(),id); }
}
