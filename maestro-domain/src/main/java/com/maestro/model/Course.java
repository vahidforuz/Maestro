package com.maestro.model;

public class Course {
    String name;
    String code;
    TypeCourse type;
    Instrument instrument;

    public Course(String name, String code, TypeCourse type, Instrument instrument) {
        this.name = name;
        this.code = code;
        this.type = type;
        this.instrument = instrument;
    }

    public String getName() {
        return name;
    }

    public String getCode() {
        return code;
    }

    public TypeCourse getType() {
        return type;
    }

    public Instrument getInstrument() {
        return instrument;
    }

    public void setName(String name) {
        this.name = name;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public void setType(TypeCourse type) {
        this.type = type;
    }

    public void setInstrument(Instrument instrument) {
        this.instrument = instrument;
    }
}
