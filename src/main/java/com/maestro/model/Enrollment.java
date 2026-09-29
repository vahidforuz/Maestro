
package com.maestro.model;

import java.time.LocalDate;

public class Enrollment {
    private Student student;
    private ClassGroup classGroup;
    private LocalDate enrollmentDate;
    private EnrollmentStatus status;

    public Enrollment(Student student, ClassGroup classGroup, LocalDate enrollmentDate, EnrollmentStatus status) {
        this.student = student;
        this.classGroup = classGroup;
        this.enrollmentDate = enrollmentDate;
        this.status = status;
    }

    public Student getStudent() {
        return student;
    }

    public ClassGroup getClassGroup() {
        return classGroup;
    }

    public LocalDate getEnrollmentDate() {
        return enrollmentDate;
    }

    public EnrollmentStatus getStatus() {
        return status;
    }

    public void setStudent(Student student) {
        this.student = student;
    }

    public void setClassGroup(ClassGroup classGroup) {
        this.classGroup = classGroup;
    }

    public void setEnrollmentDate(LocalDate enrollmentDate) {
        this.enrollmentDate = enrollmentDate;
    }

    public void setStatus(EnrollmentStatus status) {
        this.status = status;
    }
}
