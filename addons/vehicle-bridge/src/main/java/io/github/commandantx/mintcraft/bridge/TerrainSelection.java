package io.github.commandantx.mintcraft.bridge;
import java.util.List;
/** Pure query bounds and explicit server policy. */
final class TerrainSelection {
    static final int EDGE=16, RADIUS=128;
    static boolean allowed(boolean enabled,List<?> ids,int computer) {
        if (!enabled || ids==null || ids.size()>256 || computer<0) return false;
        for(Object id:ids) if(id instanceof Number n && Double.isFinite(n.doubleValue()) && n.doubleValue()==computer) return true;
        return false;
    }
    static void validate(int x,int y,int z,double px,double py,double pz,int minY,int maxY) {
        if(!Double.isFinite(px)||!Double.isFinite(py)||!Double.isFinite(pz)||Math.abs((long)x)>30_000_000||Math.abs((long)z)>30_000_000||
            x%16!=0||y%16!=0||z%16!=0||y<minY||(long)y+16>maxY||
            Math.abs(x+8.0-px)+8>128||Math.abs(y+8.0-py)+8>128||Math.abs(z+8.0-pz)+8>128)
            throw new IllegalArgumentException("One aligned world section within 128 blocks of the actual computer is required");
    }
}
