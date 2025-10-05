package com.hxgny.app.ui.classes

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hxgny.app.data.HxgnyRepository
import com.hxgny.app.model.ClassItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ClassesViewModel(
    private val repository: HxgnyRepository
) : ViewModel() {

    private val _state = MutableStateFlow(ClassesUiState())
    val state: StateFlow<ClassesUiState> = _state

    init {
        viewModelScope.launch {
            val classes = repository.loadClasses()
            val saved = repository.loadSavedClasses()
            _state.update {
                it.copy(
                    isLoading = false,
                    allClasses = classes,
                    saved = reconcileSaved(saved, classes),
                    filteredClasses = applyFilters(
                        classes = classes,
                        saved = saved,
                        query = it.query,
                        selectedCategory = it.selectedCategory,
                        onSiteOnly = it.onSiteOnly
                    ),
                    lastUpdated = repository.lastUpdatedForClasses()
                )
            }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isRefreshing = true, errorMessage = null) }
            val success = repository.refreshClasses()
            val latest = repository.loadClasses()
            val saved = repository.loadSavedClasses()
            _state.update { current ->
                val reconciledSaved = reconcileSaved(saved, latest)
                current.copy(
                    isRefreshing = false,
                    allClasses = latest,
                    saved = reconciledSaved,
                    filteredClasses = applyFilters(
                        classes = latest,
                        saved = reconciledSaved,
                        query = current.query,
                        selectedCategory = current.selectedCategory,
                        onSiteOnly = current.onSiteOnly
                    ),
                    lastUpdated = repository.lastUpdatedForClasses(),
                    errorMessage = if (success) null else current.errorMessage
                )
            }
        }
    }

    fun setQuery(query: String) {
        _state.update { state ->
            val filtered = applyFilters(
                classes = state.allClasses,
                saved = state.saved,
                query = query,
                selectedCategory = state.selectedCategory,
                onSiteOnly = state.onSiteOnly
            )
            state.copy(query = query, filteredClasses = filtered)
        }
    }

    fun selectCategory(category: String) {
        _state.update { state ->
            val filtered = applyFilters(
                classes = state.allClasses,
                saved = state.saved,
                query = state.query,
                selectedCategory = category,
                onSiteOnly = state.onSiteOnly
            )
            state.copy(selectedCategory = category, filteredClasses = filtered)
        }
    }

    fun toggleOnSiteOnly(enabled: Boolean) {
        _state.update { state ->
            val filtered = applyFilters(
                classes = state.allClasses,
                saved = state.saved,
                query = state.query,
                selectedCategory = state.selectedCategory,
                onSiteOnly = enabled
            )
            state.copy(onSiteOnly = enabled, filteredClasses = filtered)
        }
    }

    fun toggleSaved(item: ClassItem) {
        viewModelScope.launch {
            val saved = _state.value.saved.toMutableList()
            val existingIndex = saved.indexOfFirst { it.id == item.id }
            if (existingIndex >= 0) {
                saved.removeAt(existingIndex)
            } else {
                saved.add(item)
            }
            repository.saveSchedule(saved)
            val filtered = applyFilters(
                classes = _state.value.allClasses,
                saved = saved,
                query = _state.value.query,
                selectedCategory = _state.value.selectedCategory,
                onSiteOnly = _state.value.onSiteOnly
            )
            _state.update { it.copy(saved = saved, filteredClasses = filtered) }
        }
    }

    fun classById(id: String): ClassItem? {
        return _state.value.allClasses.find { it.id == id } ?: _state.value.saved.find { it.id == id }
    }

    private fun reconcileSaved(saved: List<ClassItem>, classes: List<ClassItem>): List<ClassItem> {
        if (saved.isEmpty()) return emptyList()
        val byId = classes.associateBy { it.id }
        return saved.map { byId[it.id] ?: it }
    }

    private fun applyFilters(
        classes: List<ClassItem>,
        saved: List<ClassItem>,
        query: String,
        selectedCategory: String,
        onSiteOnly: Boolean
    ): List<ClassItem> {
        val source = classes.ifEmpty { saved }
        return source
            .asSequence()
            .filter { item ->
                (!onSiteOnly || item.isOnSite()) &&
                    (selectedCategory.isBlank() || item.category.contains(selectedCategory, ignoreCase = true)) &&
                    item.matches(query)
            }
            .sortedBy { it.title }
            .toList()
    }
}

data class ClassesUiState(
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val allClasses: List<ClassItem> = emptyList(),
    val filteredClasses: List<ClassItem> = emptyList(),
    val saved: List<ClassItem> = emptyList(),
    val query: String = "",
    val selectedCategory: String = "",
    val onSiteOnly: Boolean = false,
    val lastUpdated: Long? = null,
    val errorMessage: String? = null
) {
    val categories: List<String>
        get() = allClasses.map { it.category.trim() }.filter { it.isNotBlank() }.distinct().sorted()
}
