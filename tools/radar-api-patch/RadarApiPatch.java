import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.zip.*;
import jdk.internal.org.objectweb.asm.*;
import jdk.internal.org.objectweb.asm.tree.*;
import jdk.internal.org.objectweb.asm.tree.analysis.*;

/** Read-only Lua bridge for exactly the user-provided Radar 5 EA build. */
public final class RadarApiPatch implements Opcodes {
    static final String HASH="773e0d3bf396d071753de76313dd05ac76be4be0e350255db89e15dfdd7c1b9a";
    static final String BASE="com/happysg/radar/";
    static final String BEARING=BASE+"block/radar/bearing/RadarBearingBlockEntity";
    static final String PLANE=BASE+"block/radar/plane/StationaryRadarBlockEntity";
    static final String SCANNER=BASE+"block/radar/behavior/RadarScanningBlockBehavior";
    static final String API=BASE+"compat/computercraft/RadarBearingPeripheral";
    static final String MAP="java/util/HashMap", VEC="net/minecraft/world/phys/Vec3";
    static final String INPUT="(L"+BEARING+";)";

    static MethodNode method(ClassNode owner,String name,String desc) {
        for (MethodNode m:owner.methods) if(m.name.equals(name)&&m.desc.equals(desc)) return m;
        throw new IllegalArgumentException("Unexpected JAR: missing "+owner.name+"."+name+desc);
    }
    static void field(ClassNode owner,String name,String desc) {
        for(FieldNode f:owner.fields) if(f.name.equals(name)&&f.desc.equals(desc)) return;
        throw new IllegalArgumentException("Unexpected JAR field: "+name);
    }
    static MethodNode add(ClassNode owner,String name,String desc,boolean api) {
        for(MethodNode m:owner.methods) if(m.name.equals(name)) throw new IllegalArgumentException("Already patched: "+name);
        MethodNode m=new MethodNode(ASM8,ACC_PUBLIC|(api?ACC_STATIC:0),name,desc,null,null);
        if(api) {
            AnnotationNode a=new AnnotationNode("Ldan200/computercraft/api/lua/LuaFunction;");
            a.values=new ArrayList<>(List.of("mainThread",true));
            m.visibleAnnotations=new ArrayList<>(List.of(a));
        }
        owner.methods.add(m); return m;
    }
    static void scalarGetter(ClassNode owner,String name,String member,String desc,int ret) {
        MethodNode m=add(owner,name,"()"+desc,false);
        m.visitVarInsn(ALOAD,0); m.visitFieldInsn(GETFIELD,owner.name,member,desc);
        m.visitInsn(ret); m.visitMaxs(1,1);
    }
    static void scannerGetter(ClassNode bearing,String name,String scannerName,String desc,int ret) {
        MethodNode m=add(bearing,name,"()"+desc,false);
        m.visitVarInsn(ALOAD,0); m.visitFieldInsn(GETFIELD,BEARING,"scanningBehavior","L"+SCANNER+";");
        m.visitMethodInsn(INVOKEVIRTUAL,SCANNER,scannerName,"()"+desc,false);
        m.visitInsn(ret); m.visitMaxs(1,1);
    }
    static void beginPut(MethodNode m,String key) { m.visitVarInsn(ALOAD,1); m.visitLdcInsn(key); }
    static void endPut(MethodNode m) {
        m.visitMethodInsn(INVOKEVIRTUAL,MAP,"put","(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;",false);
        m.visitInsn(POP);
    }
    static void scalarPut(MethodNode m,String key,String getter,String desc,int conversion,String box) {
        beginPut(m,key); m.visitVarInsn(ALOAD,0);
        m.visitMethodInsn(INVOKEVIRTUAL,BEARING,getter,"()"+desc,false);
        if(conversion>=0) m.visitInsn(conversion);
        m.visitMethodInsn(INVOKESTATIC,"java/lang/"+box,"valueOf",box.equals("Double")?"(D)Ljava/lang/Double;":box.equals("Boolean")?"(Z)Ljava/lang/Boolean;":"(I)Ljava/lang/Integer;",false);
        endPut(m);
    }
    static void literalPut(MethodNode m,String key,Object value) {
        beginPut(m,key); m.visitLdcInsn(value);
        if(value instanceof Integer) m.visitMethodInsn(INVOKESTATIC,"java/lang/Integer","valueOf","(I)Ljava/lang/Integer;",false);
        endPut(m);
    }
    static byte[] transform(byte[] bytes) throws Exception {
        ClassNode c=new ClassNode(ASM8); new ClassReader(bytes).accept(c,0);
        if(c.name.equals(SCANNER)) {
            field(c,"yRange","I"); method(c,"getFov","()I"); method(c,"getAngle","()F");
            scalarGetter(c,"mintcraftHalfHeight","yRange","I",IRETURN);
        } else if(c.name.equals(BEARING)) {
            field(c,"scanningBehavior","L"+SCANNER+";");
            method(c,"getAngle","()F"); method(c,"isRunning","()Z");
            scannerGetter(c,"mintcraftScanAngle","getAngle","F",FRETURN);
            scannerGetter(c,"mintcraftScanFov","getFov","I",IRETURN);
            scannerGetter(c,"mintcraftHalfHeight","mintcraftHalfHeight","I",IRETURN);
        } else if(c.name.equals(API)) {
            MethodNode position=method(c,"getPosition","(L"+PLANE+";)Ljava/util/HashMap;");
            position.desc=position.desc.replace(PLANE,BEARING);
            if(position.signature!=null) position.signature=position.signature.replace(PLANE,BEARING);
            for(AbstractInsnNode n:position.instructions) {
                if(n instanceof MethodInsnNode call && call.owner.equals(PLANE)) call.owner=BEARING;
                if(n instanceof FrameNode frame && frame.local!=null) {
                    for(int i=0;i<frame.local.size();i++) if(PLANE.equals(frame.local.get(i))) frame.local.set(i,BEARING);
                }
            }
            if(position.localVariables!=null) for(LocalVariableNode local:position.localVariables) {
                local.desc=local.desc.replace(PLANE,BEARING);
                if(local.signature!=null) local.signature=local.signature.replace(PLANE,BEARING);
            }
            MethodNode frame=add(c,"mintcraftHeadingFrame",INPUT+"Ljava/lang/String;",false);
            frame.access=ACC_PRIVATE|ACC_STATIC;
            Label world=new Label();
            frame.visitFieldInsn(GETSTATIC,BASE+"compat/Mods","SABLE","L"+BASE+"compat/Mods;");
            frame.visitMethodInsn(INVOKEVIRTUAL,BASE+"compat/Mods","isLoaded","()Z",false);
            frame.visitJumpInsn(IFEQ,world);
            frame.visitVarInsn(ALOAD,0); frame.visitMethodInsn(INVOKEVIRTUAL,BEARING,"getLevel","()Lnet/minecraft/world/level/Level;",false);
            frame.visitVarInsn(ALOAD,0); frame.visitMethodInsn(INVOKEVIRTUAL,BEARING,"getWorldPos","()Lnet/minecraft/core/BlockPos;",false);
            frame.visitMethodInsn(INVOKESTATIC,BASE+"compat/vs2/PhysicsHandler","isBlockInPlotyard","(Lnet/minecraft/world/level/Level;Lnet/minecraft/core/BlockPos;)Z",false);
            frame.visitJumpInsn(IFEQ,world); frame.visitLdcInsn("body"); frame.visitInsn(ARETURN);
            frame.visitLabel(world); frame.visitFrame(F_SAME,0,null,0,null); frame.visitLdcInsn("world"); frame.visitInsn(ARETURN); frame.visitMaxs(2,1);
            MethodNode m=add(c,"getScanGeometry",INPUT+"Ljava/util/HashMap;",true);
            m.visitTypeInsn(NEW,MAP); m.visitInsn(DUP); m.visitMethodInsn(INVOKESPECIAL,MAP,"<init>","()V",false); m.visitVarInsn(ASTORE,1);
            literalPut(m,"version",1); literalPut(m,"positionFrame","world");
            beginPut(m,"headingFrame"); m.visitVarInsn(ALOAD,0); m.visitMethodInsn(INVOKESTATIC,API,"mintcraftHeadingFrame",INPUT+"Ljava/lang/String;",false); endPut(m);
            beginPut(m,"position"); m.visitVarInsn(ALOAD,0);
            m.visitMethodInsn(INVOKESTATIC,API,"getPosition",INPUT+"Ljava/util/HashMap;",false); endPut(m);
            scalarPut(m,"heading","mintcraftScanAngle","F",F2D,"Double");
            scalarPut(m,"fov","mintcraftScanFov","I",-1,"Integer");
            scalarPut(m,"halfHeight","mintcraftHalfHeight","I",-1,"Integer");
            scalarPut(m,"rotation","getAngle","F",F2D,"Double");
            scalarPut(m,"rotationSpeed","getAngularSpeed","F",F2D,"Double");
            scalarPut(m,"range","getRange","F",F2D,"Double");
            scalarPut(m,"dishCount","getDishCount","I",-1,"Integer");
            scalarPut(m,"running","isRunning","Z",-1,"Boolean");
            m.visitVarInsn(ALOAD,1); m.visitInsn(ARETURN); m.visitMaxs(5,2);
        } else throw new IllegalArgumentException(c.name);
        ClassWriter w=new ClassWriter(ClassWriter.COMPUTE_MAXS); c.accept(w);
        byte[] output=w.toByteArray();
        ClassNode check=new ClassNode(ASM8); new ClassReader(output).accept(check,ClassReader.EXPAND_FRAMES);
        for(MethodNode m:check.methods) if((m.access&(ACC_ABSTRACT|ACC_NATIVE))==0) new Analyzer<>(new BasicVerifier()).analyze(check.name,m);
        return output;
    }
    public static void main(String[] args) throws Exception {
        if(args.length!=2) throw new IllegalArgumentException("Usage: RadarApiPatch INPUT.jar NEW_OUTPUT.jar");
        Path input=Path.of(args[0]).toRealPath(),output=Path.of(args[1]).toAbsolutePath().normalize();
        if(Files.exists(output)) throw new IllegalArgumentException("Output exists; refusing overwrite");
        String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(input)));
        if(!HASH.equals(hash)) throw new IllegalArgumentException("Wrong JAR SHA-256: "+hash);
        Map<String,byte[]> replacements=new HashMap<>();
        try(ZipFile zip=new ZipFile(input.toFile())) {
            for(String name:List.of(SCANNER,BEARING,API)) {
                ZipEntry e=Objects.requireNonNull(zip.getEntry(name+".class"),name);
                replacements.put(e.getName(),transform(zip.getInputStream(e).readAllBytes()));
            }
            for(ZipEntry e:Collections.list(zip.entries())) {
                String name=e.getName().toUpperCase(Locale.ROOT);
                if(name.startsWith("META-INF/")&&(name.endsWith(".SF")||name.endsWith(".RSA")||name.endsWith(".DSA"))) throw new IllegalArgumentException("Signed JAR: refusing patch");
            }
            boolean complete=false;
            try {
                try(ZipOutputStream out=new ZipOutputStream(Files.newOutputStream(output,StandardOpenOption.CREATE_NEW))) {
                    for(ZipEntry e:Collections.list(zip.entries())) {
                        ZipEntry copy=new ZipEntry(e.getName()); copy.setTime(e.getTime()); out.putNextEntry(copy);
                        if(!e.isDirectory()) out.write(replacements.containsKey(e.getName())?replacements.get(e.getName()):zip.getInputStream(e).readAllBytes());
                        out.closeEntry();
                    }
                }
                complete=true;
            } finally { if(!complete) Files.deleteIfExists(output); }
        }
        System.out.println("Created "+output+"; modified exactly three classes; input unchanged. Bytecode stack verification passed.");
        System.out.println("This is an experimental read-only bridge, not an official Radar build. In-game validation required.");
    }
}
