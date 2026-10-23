package io.github.commandantx.mintcraft.bridge;
import java.util.List;
import java.util.Collections;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class TerrainSelectionTest {
    @Test void policyRequiresExplicitServerOptInAndComputerId() {
        assertFalse(TerrainSelection.allowed(false,List.of(7),7));
        assertFalse(TerrainSelection.allowed(true,List.of(),7));
        assertFalse(TerrainSelection.allowed(true,List.of(8),7));
        assertFalse(TerrainSelection.allowed(true,List.of("7"),7));
        assertFalse(TerrainSelection.allowed(true,Collections.nCopies(257,7),7));
        assertTrue(TerrainSelection.allowed(true,List.of(7,8),7));
    }
    @Test void onlyAlignedBoundedSectionsInActualWorldHeightAndLocalRange() {
        TerrainSelection.validate(0,64,0,8,72,8,-64,320);
        TerrainSelection.validate(-128,-64,-128,0,0,0,-64,320);
        for(int[] p:List.of(new int[]{1,64,0},new int[]{0,65,0},new int[]{0,64,1},new int[]{128,64,0},
            new int[]{0,320,0},new int[]{0,-80,0},new int[]{Integer.MAX_VALUE,64,0}))
            assertThrows(IllegalArgumentException.class,()->TerrainSelection.validate(p[0],p[1],p[2],8,72,8,-64,320));
        assertThrows(IllegalArgumentException.class,()->TerrainSelection.validate(0,64,0,Double.NaN,72,8,-64,320));
    }
}
