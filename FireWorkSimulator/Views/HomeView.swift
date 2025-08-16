import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("花火シミュレーター")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
//                NavigationLink(destination: EditorView()) {
//                    Text("花火玉エディタ")
//                        .font(.title2)
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.blue.opacity(0.2))
//                        .cornerRadius(12)
//                }
                NavigationLink(destination: ShellListView()) {
                    Text("作成済み花火玉一覧")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                }
                NavigationLink(destination: ARViewScreen()) {
                    Text("ARで打ち上げ")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("ホーム")
            .onAppear {
                print("HomeView appeared successfully")
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
} 
