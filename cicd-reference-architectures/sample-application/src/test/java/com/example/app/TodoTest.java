package com.example.app;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class TodoTest {

    @Test
    void defaultCompletedValueIsFalse() {
        Todo todo = new Todo();
        todo.setTitle("Add coverage");

        assertThat(todo.getCompleted()).isFalse();
    }

    @Test
    void allArgsConstructorSetsFields() {
        Todo todo = new Todo(1L, "Title", "Description", true);

        assertThat(todo.getId()).isEqualTo(1L);
        assertThat(todo.getTitle()).isEqualTo("Title");
        assertThat(todo.getDescription()).isEqualTo("Description");
        assertThat(todo.getCompleted()).isTrue();
    }
}