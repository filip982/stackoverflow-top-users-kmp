package dev.filip.sotopusers.android

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import dev.filip.sotopusers.android.detail.UserDetailRoute
import dev.filip.sotopusers.android.detail.UserDetailStore
import dev.filip.sotopusers.android.list.ListStatus
import dev.filip.sotopusers.android.list.UserListIntent
import dev.filip.sotopusers.android.list.UserListRoute
import dev.filip.sotopusers.android.list.UserListStore
import dev.filip.sotopusers.android.mvi.StoreViewModel
import dev.filip.sotopusers.android.sort.SortOptionsRoute
import dev.filip.sotopusers.android.sort.SortOptionsStore
import dev.filip.sotopusers.android.ui.BackNavScaffold
import kotlinx.coroutines.CoroutineScope

private object Routes {
    const val LIST = "users"
    const val DETAIL = "users/{id}"
    const val SORT = "sort"
    fun detail(id: Long) = "users/$id"
}

/** Store scoped to a back-stack entry's ViewModelStore (survives configuration changes). */
@Composable
private fun <T : Any> rememberStore(owner: ViewModelStoreOwner, key: String, create: (CoroutineScope) -> T): T =
    viewModel<StoreViewModel<T>>(
        viewModelStoreOwner = owner,
        key = key,
        factory = viewModelFactory { initializer { StoreViewModel(create) } },
    ).store

@Composable
private fun listStore(nav: NavHostController, container: AppContainer): UserListStore {
    // Detail and sort read/write the list store, so it is always resolved from the list entry.
    val listEntry = remember(nav) { nav.getBackStackEntry(Routes.LIST) }
    return rememberStore(listEntry, "list") { scope ->
        val core = container.core
        UserListStore(
            scope = scope,
            getTopUsers = core.getTopUsers,
            toggleFollow = core.toggleFollow,
            sortUsers = core.sortUsers,
            followedIds = core.repository.followedIdsFlow,
            startupStorageError = container.startupNotice.take(),
        )
    }
}

@Composable
fun AppNavHost(container: AppContainer, nav: NavHostController = rememberNavController()) {
    NavHost(navController = nav, startDestination = Routes.LIST) {
        composable(Routes.LIST) {
            UserListRoute(
                store = listStore(nav, container),
                onUserClick = { nav.navigate(Routes.detail(it.id)) },
                onSortClick = { nav.navigate(Routes.SORT) { launchSingleTop = true } },
            )
        }

        composable(Routes.DETAIL, arguments = listOf(navArgument("id") { type = NavType.LongType })) { entry ->
            val id = entry.arguments?.getLong("id")
            val listState by listStore(nav, container).state.collectAsStateWithLifecycle()
            val user = listState.users.firstOrNull { it.id == id }
            val back: () -> Unit = { nav.popBackStack(Routes.DETAIL, inclusive = true) }
            if (user == null) {
                // Only reachable after process death, before the list has reloaded.
                BackNavScaffold(title = "", onBack = back) { modifier ->
                    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        if (listState.status == ListStatus.Loading) CircularProgressIndicator() else Text("User not available")
                    }
                }
            } else {
                val store = rememberStore(entry, "detail") { scope ->
                    UserDetailStore(scope, user, container.core.toggleFollow, container.core.repository.followedIdsFlow)
                }
                UserDetailRoute(store, onBack = back)
            }
        }

        composable(Routes.SORT) { entry ->
            val list = listStore(nav, container)
            val store = rememberStore(entry, "sort") { scope -> SortOptionsStore(scope, list.state.value.sort) }
            SortOptionsRoute(
                store = store,
                onApplied = { option ->
                    list.dispatch(UserListIntent.ApplySort(option))
                    nav.popBackStack(Routes.SORT, inclusive = true)
                },
                onDismissed = { nav.popBackStack(Routes.SORT, inclusive = true) },
            )
        }
    }
}
