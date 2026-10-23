package io.github.commandantx.mintcraft.bridge;

/** Shared server-wide node budget. Main-thread callers only. */
final class FeedbackBudget {
    private final int maximum;
    private long tick = Long.MIN_VALUE;
    private int used;
    FeedbackBudget(int maximum) {
        if (maximum < 1) throw new IllegalArgumentException("budget");
        this.maximum = maximum;
    }
    boolean claim(long current, int count) {
        if (count < 1 || count > maximum) return false;
        if (current != tick) { tick = current; used = 0; }
        if (count > maximum - used) return false;
        used += count;
        return true;
    }
}
