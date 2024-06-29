//
//  PopResultView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI

struct PopResultView: View {
    var text: String

    var body: some View {
        VStack(alignment: .center){
            Text(text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 10).padding(.leading, 10).padding(.trailing, 10)
                .background(.gray).cornerRadius(5).fixedSize()
        }
    }
}
