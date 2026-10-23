import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import org.squiddev.cobalt.LuaState;
import org.squiddev.cobalt.LuaThread;
import org.squiddev.cobalt.compiler.LoadState;
import org.squiddev.cobalt.lib.CoreLibraries;

/** Compile installed chunks with the interpreter shipped in CC:Tweaked. No world access. */
public final class VerifyPackedCobalt {
    public static void main(String[] args) throws Exception {
        boolean run = args.length == 2 && args[0].equals("--probe");
        LuaState state = new LuaState();
        CoreLibraries.standardGlobals(state);
        int count = 0;
        for (int i = run ? 1 : 0; i < args.length; i++) {
            byte[] bytes = Files.readAllBytes(Path.of(args[i]));
            if (!Arrays.equals(bytes, new String(bytes, StandardCharsets.UTF_8).getBytes(StandardCharsets.UTF_8))) {
                throw new AssertionError("Non-lossless UTF-8 source: " + args[i]);
            }
            var chunk = LoadState.load(state, new ByteArrayInputStream(bytes), "@" + args[i], state.globals());
            if (run && LuaThread.runMain(state, chunk).first().checkInteger() != 4) {
                throw new AssertionError("Unexpected decoder fixture result");
            }
            count++;
        }
        System.out.println("Cobalt: " + count + (run ? " decoder fixture probe passed" : " chunks compiled") + "; UTF-8 round-trips exact");
    }
}
