package io.github.commandantx.mintcraft.bridge;

import java.util.Map;

final class BridgeMath {
    private BridgeMath() {}
    static Map<String, Double> vector(double x, double y, double z) {
        if (!(Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)))
            throw new IllegalArgumentException("non-finite vector");
        return Map.of("x", x, "y", y, "z", z);
    }
    static Map<String, Double> relative(double x, double y, double z, double ox, double oy, double oz) {
        return vector(x - ox, y - oy, z - oz);
    }
    static Map<String, Double> torque(double x, double y, double z, double fx, double fy, double fz) {
        return vector(y * fz - z * fy, z * fx - x * fz, x * fy - y * fx);
    }
    static String role(double x, double y, double z) {
        double norm = Math.sqrt(x*x + y*y + z*z);
        if (!Double.isFinite(norm) || norm < 1e-8) return "unknown";
        if (Math.abs(y)/norm > 0.85) return "lift";
        if (Math.abs(z)/norm > 0.85) return "propulsion";
        if (Math.abs(x)/norm > 0.85) return "strafe";
        return "mixed";
    }
}
