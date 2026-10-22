package io.github.commandantx.mintcraft.bridge;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class VoxelCodecTest {
 @Test void losslessSparseRunsAndAir() {
  int[] cells=new int[4096]; assertEquals("",VoxelCodec.encode(cells));
  java.util.Arrays.fill(cells,0,16,1); cells[256]=2; cells[4095]=3;
  assertEquals("0:16:1;256:1:2;4095:1:3;",VoxelCodec.encode(cells));
 }
 @Test void alternatingWorstCaseFitsPayloadBudget() {
  int[] cells=new int[4096]; for(int i=0;i<4096;i++) cells[i]=i+1;
  String encoded=VoxelCodec.encode(cells); assertTrue(encoded.length()<=65536);
  assertEquals(4096,encoded.chars().filter(c->c==';').count());
 }
 @Test void invalidPaletteOrSectionRejected() {
  assertThrows(IllegalArgumentException.class,()->VoxelCodec.encode(new int[4095]));
  int[] bad=new int[4096];bad[17]=-1;
  assertThrows(IllegalArgumentException.class,()->VoxelCodec.encode(bad));
 }
}
