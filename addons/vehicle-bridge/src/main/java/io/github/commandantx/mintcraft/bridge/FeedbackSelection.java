package io.github.commandantx.mintcraft.bridge;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Strict selection of previously inventoried parent-plot nodes. No world IO. */
final class FeedbackSelection {
    static final int MAX = 64;
    record Target(String id, int x, int y, int z) {}
    static List<Target> parse(String vehicle, Map<?,?> requested, Set<String> known) {
        if (vehicle == null || vehicle.isEmpty() || vehicle.length() > 128 || requested == null || requested.isEmpty() || requested.size() > MAX)
            throw new IllegalArgumentException("selection bounds");
        var result = new ArrayList<Target>();
        var keys = new HashSet<Integer>();
        var ids = new HashSet<String>();
        for (var entry : requested.entrySet()) {
            if (!(entry.getKey() instanceof Number n) || !Double.isFinite(n.doubleValue()) || n.doubleValue() != Math.rint(n.doubleValue()) ||
                n.doubleValue() < 1 || n.doubleValue() > requested.size() || !keys.add(n.intValue()) ||
                !(entry.getValue() instanceof String id) || id.length() > 192 || !id.startsWith(vehicle + ":") || !known.contains(id) || !ids.add(id))
                throw new IllegalArgumentException("unknown or malformed selection");
            String[] coordinates = id.substring(vehicle.length() + 1).split(":", -1);
            if (coordinates.length != 3) throw new IllegalArgumentException("coordinate count");
            int x = coordinate(coordinates[0]), y = coordinate(coordinates[1]), z = coordinate(coordinates[2]);
            result.add(new Target(id,x,y,z));
        }
        result.sort(java.util.Comparator.comparing(Target::id));
        return List.copyOf(result);
    }
    private static int coordinate(String value) {
        if (value.isEmpty() || value.length() > 8 || !value.matches("-?[0-9]+")) throw new IllegalArgumentException("coordinate format");
        int number = Integer.parseInt(value);
        if (Math.abs((long) number) > 1_000_000) throw new IllegalArgumentException("coordinate bounds");
        return number;
    }
}
