import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    let onComplete: (String) -> Void
    
    @State private var username: String = ""
    @State private var isValidating = false
    @State private var error: String = ""
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.1),
                    Color(red: 0.1, green: 0.06, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Welcome Section
                    VStack(spacing: 16) {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        
                        Text("Welcome to DramaTrack")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Track your favorite Asian dramas")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 16)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 20) {
                        InstructionRow(
                            number: 1,
                            icon: "person.fill",
                            title: "Enter your MyDramaList username",
                            description: "We'll sync your watchlist automatically"
                        )
                        
                        InstructionRow(
                            number: 2,
                            icon: "globe",
                            title: "Make sure your list is public",
                            description: "Go to Settings > Privacy on MyDramaList"
                        )
                        
                        InstructionRow(
                            number: 3,
                            icon: "bell.fill",
                            title: "Enable notifications",
                            description: "Get notified when new episodes air"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Username Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MyDramaList Username")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .foregroundColor(.gray)
                            
                            TextField("username", text: $username)
                                .foregroundColor(.white)
                                .textFieldStyle(.plain)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .disabled(isValidating)
                                .onChange(of: username) { _, _ in
                                    error = ""
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        if !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Get Started Button
                    Button(action: handleGetStarted) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Validating...")
                                    .font(.system(size: 16, weight: .semibold))
                            } else {
                                Text("Get Started")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            username.isEmpty || isValidating
                            ? Color.gray.opacity(0.3)
                            : Color(red: 0.86, green: 0.5, blue: 1.0)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(username.isEmpty || isValidating)
                    .padding(.horizontal, 24)
                    
                    // Sign up link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.gray)
                        
                        Link("Sign up on MyDramaList", destination: URL(string: "https://mydramalist.com/signup")!)
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                    }
                    .font(.system(size: 14))
                    
                    Spacer()
                }
            }
        }
    }
    
    private func handleGetStarted() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUsername.isEmpty else {
            error = "Please enter a username"
            return
        }
        
        // Validate username exists on MyDramaList
        Task {
            isValidating = true
            error = ""
            
            do {
                let isValid = try await validateUsername(trimmedUsername)
                
                await MainActor.run {
                    isValidating = false
                    
                    if isValid {
                        onComplete(trimmedUsername)
                    } else {
                        error = "Username not found on MyDramaList"
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    self.error = "Unable to verify username. Please check your connection."
                }
            }
        }
    }
    
    private func validateUsername(_ username: String) async throws -> Bool {
        try await APIClient.shared.validateUsername(username)
    }
}

struct InstructionRow: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 0.5, blue: 1.0))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                .frame(width: 32)
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false)) { _ in }
}
