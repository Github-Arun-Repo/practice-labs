package com.example.app;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TodoController.class)
@SuppressWarnings("null")
class TodoControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private TodoRepository todoRepository;

    @Test
    void getAllTodosReturnsRepositoryItems() throws Exception {
        when(todoRepository.findAll()).thenReturn(List.of(
                new Todo(1L, "Build pipeline", "Add reports", false),
                new Todo(2L, "Publish image", "Push to registry", true)
        ));

        mockMvc.perform(get("/api/todos"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].title").value("Build pipeline"))
                .andExpect(jsonPath("$[1].completed").value(true));
    }

    @Test
    void getTodoByIdReturnsNotFoundWhenMissing() throws Exception {
        when(todoRepository.findById(99L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/todos/99"))
                .andExpect(status().isNotFound());
    }

    @Test
    void createTodoPersistsAndReturnsCreatedTodo() throws Exception {
        Todo request = new Todo(null, "Create tests", "Cover controller", false);
        Todo saved = new Todo(10L, "Create tests", "Cover controller", false);

        when(todoRepository.save(any(Todo.class))).thenReturn(saved);

        mockMvc.perform(post("/api/todos")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(10))
                .andExpect(jsonPath("$.title").value("Create tests"));
    }

    @Test
    void updateTodoChangesExistingTodo() throws Exception {
        Todo existing = new Todo(3L, "Old title", "Old description", false);
        Todo update = new Todo(null, "New title", "New description", true);
        Todo updated = new Todo(3L, "New title", "New description", true);

        when(todoRepository.findById(3L)).thenReturn(Optional.of(existing));
        when(todoRepository.save(any(Todo.class))).thenReturn(updated);

        mockMvc.perform(put("/api/todos/3")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("New title"))
                .andExpect(jsonPath("$.completed").value(true));
    }

    @Test
    void deleteTodoDeletesExistingTodo() throws Exception {
        Todo existing = new Todo(4L, "Delete me", "Remove item", false);
        when(todoRepository.findById(4L)).thenReturn(Optional.of(existing));

        mockMvc.perform(delete("/api/todos/4"))
                .andExpect(status().isNoContent());

        verify(todoRepository).delete(existing);
    }

    @Test
    void healthReturnsHealthyMessage() throws Exception {
        mockMvc.perform(get("/api/todos/health"))
                .andExpect(status().isOk())
                .andExpect(content().string("TODO App is healthy"));
    }
}