package io.github.commandantx.mintcraft.bridge;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class BridgeMathTest {
    @Test void structuralBalloonAssociationDoesNotRequireGas() {
        assertTrue(BridgeMath.balloonAssociated(true,64,true));
        assertFalse(BridgeMath.balloonAssociated(false,64,true));
        assertFalse(BridgeMath.balloonAssociated(true,0,true));
        assertFalse(BridgeMath.balloonAssociated(true,-1,true));
        assertFalse(BridgeMath.balloonAssociated(true,64,false));
    }
    @Test void plotOriginCancelsFromMomentArm() {
        var pos=BridgeMath.relative(100002.5,70.5,100003.5,100000,64,100000);
        var com=BridgeMath.relative(100000.5,70.5,100000.5,100000,64,100000);
        var torque=BridgeMath.torque(pos.get("x")-com.get("x"),0,pos.get("z")-com.get("z"),0,10,0);
        assertEquals(-30.0,torque.get("x")); assertEquals(20.0,torque.get("z"));
    }
    @Test void offCenterRearThrustTilts() {
        var torque=BridgeMath.torque(0,2,-4,0,0,100);
        assertEquals(200.0,torque.get("x")); assertEquals(0.0,torque.get("y"),1e-12);
    }
    @Test void orientationOnlyRoleIsNotAControlBinding() {
        assertEquals("lift",BridgeMath.role(0,-1,0));
        assertEquals("propulsion",BridgeMath.role(0,0,-1));
        assertEquals("strafe",BridgeMath.role(1,0,0));
        assertEquals("mixed",BridgeMath.role(1,1,1));
        assertEquals("unknown",BridgeMath.role(0,0,0));
    }
    @Test void invalidNumericsAreNotExported() {
        assertThrows(IllegalArgumentException.class,()->BridgeMath.vector(Double.NaN,0,0));
        assertThrows(IllegalArgumentException.class,()->BridgeMath.vector(0,Double.POSITIVE_INFINITY,0));
        assertThrows(IllegalArgumentException.class,()->BridgeMath.torque(1e308,1e308,0,1e308,0,0));
    }
}
