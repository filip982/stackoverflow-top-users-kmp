package dev.filip.sotopusers.android.mvi

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update

/**
 * Minimal hand-rolled MVI store: `dispatch(intent)` -> side effects (in the store) -> messages ->
 * pure `reduce(state, message)` -> [state]. One-shot outputs (navigation) go through [effects].
 *
 * Stores take their [CoroutineScope] so tests can drive them with a controlled dispatcher; in the
 * app they live inside a [StoreViewModel] and use `viewModelScope`.
 */
abstract class Store<S, I, M, E>(initial: S, protected val scope: CoroutineScope) {
    private val mutableState = MutableStateFlow(initial)
    val state: StateFlow<S> = mutableState.asStateFlow()

    private val effectChannel = Channel<E>(Channel.BUFFERED)
    val effects: Flow<E> = effectChannel.receiveAsFlow()

    abstract fun dispatch(intent: I)

    /** Pure state transition. Must not launch work or touch anything but its arguments. */
    protected abstract fun reduce(state: S, message: M): S

    protected fun apply(message: M) = mutableState.update { reduce(it, message) }

    protected fun emit(effect: E) {
        effectChannel.trySend(effect)
    }
}

/** Lifecycle holder: survives configuration changes and cancels the store's work in onCleared. */
class StoreViewModel<T : Any>(create: (CoroutineScope) -> T) : ViewModel() {
    val store: T = create(viewModelScope)
}
