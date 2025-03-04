import DesignSystem
import Env
import Models
import Network
import Shimmer
import SwiftUI

public struct ConversationsListView: View {
  @EnvironmentObject private var preferences: UserPreferences
  @EnvironmentObject private var routerPath: RouterPath
  @EnvironmentObject private var watcher: StreamWatcher
  @EnvironmentObject private var client: Client
  @EnvironmentObject private var theme: Theme

  @StateObject private var viewModel = ConversationsListViewModel()

  public init() {}

  private var conversations: Binding<[Conversation]> {
    if viewModel.isLoadingFirstPage {
      return Binding.constant(Conversation.placeholders())
    } else {
      return $viewModel.conversations
    }
  }

  public var body: some View {
    ScrollView {
      LazyVStack {
        Group {
          if !conversations.isEmpty || viewModel.isLoadingFirstPage {
            ForEach(conversations) { $conversation in
              if viewModel.isLoadingFirstPage {
                ConversationsListRow(conversation: $conversation, viewModel: viewModel)
                  .padding(.horizontal, .layoutPadding)
                  .redacted(reason: .placeholder)
              } else {
                ConversationsListRow(conversation: $conversation, viewModel: viewModel)
                  .padding(.horizontal, .layoutPadding)
              }
              Divider()
            }
          } else if conversations.isEmpty && !viewModel.isLoadingFirstPage && !viewModel.isError {
            EmptyView(iconName: "tray",
                      title: "conversations.empty.title",
                      message: "conversations.empty.message")
          } else if viewModel.isError {
            ErrorView(title: "conversations.error.title",
                      message: "conversations.error.message",
                      buttonTitle: "conversations.error.button") {
              Task {
                await viewModel.fetchConversations()
              }
            }
          }

          if viewModel.nextPage != nil {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
            .onAppear {
              if !viewModel.isLoadingNextPage {
                Task {
                  await viewModel.fetchNextPage()
                }
              }
            }
          }
        }
      }
      .padding(.top, .layoutPadding)
    }
    .scrollContentBackground(.hidden)
    .background(theme.primaryBackgroundColor)
    .navigationTitle("conversations.navigation-title")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      StatusEditorToolbarItem(visibility: .direct)
      if UIDevice.current.userInterfaceIdiom == .pad && !preferences.showiPadSecondaryColumn {
        SecondaryColumnToolbarItem()
      }
    }
    .onChange(of: watcher.latestEvent?.id) { _ in
      if let latestEvent = watcher.latestEvent {
        viewModel.handleEvent(event: latestEvent)
      }
    }
    .refreshable {
      // note: this Task wrapper should not be necessary, but it reportedly crashes without it
      // when refreshing on an empty list
      Task {
        SoundEffectManager.shared.playSound(of: .pull)
        HapticManager.shared.fireHaptic(of: .dataRefresh(intensity: 0.3))
        await viewModel.fetchConversations()
        HapticManager.shared.fireHaptic(of: .dataRefresh(intensity: 0.7))
        SoundEffectManager.shared.playSound(of: .refresh)
      }
    }
    .onAppear {
      viewModel.client = client
      if client.isAuth {
        Task {
          await viewModel.fetchConversations()
        }
      }
    }
  }
}
