package io.github.commandantx.mintcraft.bridge;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class FeedbackSelectionTest {
    @Test void acceptsOnlyBoundedDenseKnownParentIds() {
        var known=Set.of("ship:-1:2:3","ship:4:5:6");
        var selected=FeedbackSelection.parse("ship",Map.of(2.0,"ship:4:5:6",1.0,"ship:-1:2:3"),known);
        assertEquals(2,selected.size()); assertEquals(-1,selected.getFirst().x());
        for(var invalid: java.util.List.of(Map.of(),Map.of(0,"ship:-1:2:3"),Map.of(2,"ship:-1:2:3"),Map.of(1,"foreign:-1:2:3"),
            Map.of(1,"ship:9:9:9"),Map.of(1,"ship:-1:2:3",2,"ship:-1:2:3"),Map.of(1.5,"ship:-1:2:3")))
            assertThrows(IllegalArgumentException.class,()->FeedbackSelection.parse("ship",invalid,known));
        var excessive=new LinkedHashMap<Integer,String>(); for(int i=1;i<=65;i++) excessive.put(i,"ship:"+i+":0:0");
        assertThrows(IllegalArgumentException.class,()->FeedbackSelection.parse("ship",excessive,Set.copyOf(excessive.values())));
        for(String value:java.util.List.of("ship:1000001:0:0","ship:+1:0:0","ship:1:0:0:0","ship:2147483648:0:0"))
            assertThrows(IllegalArgumentException.class,()->FeedbackSelection.parse("ship",Map.of(1,value),Set.of(value)));
    }
    @Test void globalBudgetNeverExceedsFixedNodesPerGameTick() {
        var budget=new FeedbackBudget(256);
        for(int i=0;i<4;i++) assertTrue(budget.claim(10,64));
        assertFalse(budget.claim(10,1)); assertFalse(budget.claim(10,0)); assertFalse(budget.claim(10,257));
        assertTrue(budget.claim(11,64)); assertTrue(budget.claim(9,64));
    }
}
