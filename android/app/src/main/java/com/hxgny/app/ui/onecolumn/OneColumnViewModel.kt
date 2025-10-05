package com.hxgny.app.ui.onecolumn

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hxgny.app.data.HxgnyRepository
import com.hxgny.app.data.OneColumnSlug
import com.hxgny.app.model.OneColumnItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class OneColumnViewModel(
    private val slug: OneColumnSlug,
    private val repository: HxgnyRepository
) : ViewModel() {

    private val _state = MutableStateFlow(OneColumnUiState(slug = slug))
    val state: StateFlow<OneColumnUiState> = _state

    init {
        viewModelScope.launch {
            val cached = repository.loadOneColumn(slug)
            _state.update {
                it.copy(
                    isLoading = false,
                    items = cached,
                    lastUpdated = repository.lastUpdatedForOneColumn(slug)
                )
            }
            refreshInternal()
        }
    }

    fun refresh() {
        viewModelScope.launch { refreshInternal() }
    }

    private suspend fun refreshInternal() {
        _state.update { it.copy(isRefreshing = true, errorMessage = null) }
        val success = repository.refreshOneColumn(slug)
        val latest = repository.loadOneColumn(slug)
        _state.update {
            it.copy(
                isRefreshing = false,
                items = latest,
                lastUpdated = repository.lastUpdatedForOneColumn(slug),
                errorMessage = if (success) null else it.errorMessage
            )
        }
    }
}

data class OneColumnUiState(
    val slug: OneColumnSlug,
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val items: List<OneColumnItem> = emptyList(),
    val lastUpdated: Long? = null,
    val errorMessage: String? = null
)
