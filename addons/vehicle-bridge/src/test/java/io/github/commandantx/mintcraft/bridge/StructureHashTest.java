package io.github.commandantx.mintcraft.bridge;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class StructureHashTest {
 @Test void operatingPowerDoesNotInvalidateButShapeDoes() {
  var a=StructureHash.state("create:gearshift",java.util.Map.of("axis","x","powered","false"));
  var b=StructureHash.state("create:gearshift",java.util.Map.of("powered","true","axis","x"));
  assertEquals(a,b);
  assertNotEquals(a,StructureHash.state("create:gearshift",java.util.Map.of("axis","z","powered","false")));
 }
 @Test void stableSHA256AndDistinctStructure() {
  assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",StructureHash.digest("abc"));
  assertNotEquals(StructureHash.digest("stone|axis=x"),StructureHash.digest("stone|axis=z"));
  assertEquals(64,StructureHash.digest("").length());
 }
}
