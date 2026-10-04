package com.maestro.model;

public enum Instrument {
    PIANO,
    GUITAR,
    VIOLIN,
    DRUMS,
    FLUTE,
    SAXOPHONE,
    TRUMPET,
    CELLO,
    HARP,
    CLARINET;

    @Override
    public String toString() {
        String lowerName = name().toLowerCase();
        return lowerName.substring(0, 1).toUpperCase() + lowerName.substring(1);
    }
}
