import DesignSystem
import Env
import SwiftUI

public struct AppAccountsSelectorView: View {
  @EnvironmentObject private var preferences: UserPreferences
  @EnvironmentObject private var currentAccount: CurrentAccount
  @EnvironmentObject private var appAccounts: AppAccountsManager
  @EnvironmentObject private var theme: Theme

  @ObservedObject var routerPath: RouterPath

  @State private var accountsViewModel: [AppAccountViewModel] = []
  @State private var isPresented: Bool = false

  private let accountCreationEnabled: Bool
  private let avatarSize: AvatarView.Size

  var showNotificationBadge: Bool {
    accountsViewModel
      .filter { $0.account?.id != currentAccount.account?.id }
      .compactMap { $0.appAccount.oauthToken }
      .map { preferences.getNotificationsCount(for: $0) }
      .reduce(0, +) > 0
  }

  public init(routerPath: RouterPath,
              accountCreationEnabled: Bool = true,
              avatarSize: AvatarView.Size = .badge)
  {
    self.routerPath = routerPath
    self.accountCreationEnabled = accountCreationEnabled
    self.avatarSize = avatarSize
  }

  public var body: some View {
    Button {
      isPresented.toggle()
      HapticManager.shared.fireHaptic(of: .buttonPress)
    } label: {
      labelView
    }
    .sheet(isPresented: $isPresented, content: {
      accountsView.presentationDetents([.medium, .large])
      .onAppear {
        refreshAccounts()
      }
    })
    .onChange(of: currentAccount.account?.id) { _ in
      refreshAccounts()
    }
    .onAppear {
      refreshAccounts()
    }
  }

  @ViewBuilder
  private var labelView: some View {
    Group {
      if let avatar = currentAccount.account?.avatar, !currentAccount.isLoadingAccount {
        AvatarView(url: avatar, size: avatarSize)
      } else {
        AvatarView(url: nil, size: avatarSize)
          .redacted(reason: .placeholder)
      }
    }.overlay(alignment: .topTrailing) {
      if (!currentAccount.followRequests.isEmpty || showNotificationBadge) && accountCreationEnabled {
        Circle()
          .fill(Color.red)
          .frame(width: 9, height: 9)
      }
    }
    .accessibilityLabel("accessibility.app-account.selector.accounts")
  }

  private var accountsView: some View {
    NavigationStack {
      List {
        Section {
          ForEach(accountsViewModel.sorted { $0.acct < $1.acct }, id: \.appAccount.id) { viewModel in
            AppAccountView(viewModel: viewModel)
          }
        }
        .listRowBackground(theme.primaryBackgroundColor)
        
        if accountCreationEnabled {
          Section {
            Button {
              isPresented = false
              HapticManager.shared.fireHaptic(of: .buttonPress)
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                routerPath.presentedSheet = .addAccount
              }
            } label: {
              Label("app-account.button.add", systemImage: "person.badge.plus")
            }
            settingsButton
          }
          .listRowBackground(theme.primaryBackgroundColor)
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
      .navigationTitle("settings.section.accounts")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            isPresented.toggle()
          } label: {
            Image(systemName: "xmark.circle")
          }
        }
      }
    }
  }
  
  private var settingsButton: some View {
    Button {
      isPresented = false
      HapticManager.shared.fireHaptic(of: .buttonPress)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        routerPath.presentedSheet = .settings
      }
    } label: {
      Label("tab.settings", systemImage: "gear")
    }
  }

  private func refreshAccounts() {
    accountsViewModel = []
    for account in appAccounts.availableAccounts {
      let viewModel: AppAccountViewModel = .init(appAccount: account, isInNavigation: false, showBadge: true)
      accountsViewModel.append(viewModel)
    }
  }
}
