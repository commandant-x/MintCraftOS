import java.nio.file.*;
import dev.devce.rocketnautics.shaded.luaj.vm2.*;
import dev.devce.rocketnautics.shaded.luaj.vm2.lib.jse.JsePlatform;
/** Runs Lua fixtures using the actual shaded interpreter in Cosmonautics. No game access. */
public final class VerifySputnikLua {
 public static void main(String[] args) throws Exception {
  Globals globals=JsePlatform.standardGlobals();
  for(String path:args) globals.load(Files.readString(Path.of(path)),"@"+path).call();
  System.out.println("Sputnik LuaJ: "+args.length+" fixture chunks passed in actual Cosmonautics interpreter");
 }
}
