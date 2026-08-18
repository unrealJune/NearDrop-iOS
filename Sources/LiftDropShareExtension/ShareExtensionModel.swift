import Foundation
import NearbyShareCore
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
final class ShareExtensionModel:NSObject, ObservableObject{
	enum Phase:Equatable{
		case loading
		case choosing
		case connecting(String)
		case approval(String)
		case sending(Double)
		case complete
		case failed(String)
	}

	@Published private(set) var phase=Phase.loading
	@Published private(set) var devices:[RemoteDeviceInfo]=[]
	@Published private(set) var itemCount=0
	@Published var qrCodeURL:URL?

	private weak var extensionContext:NSExtensionContext?
	private let manager=NearbyConnectionManager.shared
	private var urls:[URL]=[]
	private var selectedDevice:RemoteDeviceInfo?
	private var discoveryRunning=false
	private var qrCodeTransferPending=false

	init(extensionContext:NSExtensionContext?){
		self.extensionContext=extensionContext
		super.init()
		manager.localDeviceName=UIDevice.current.name
		manager.localDeviceType=UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .phone
		manager.addShareExtensionDelegate(self)
		manager.startDeviceDiscovery()
		discoveryRunning=true
		Task{await loadItems()}
	}

	deinit{
		manager.removeShareExtensionDelegate(self)
		if discoveryRunning{manager.stopDeviceDiscovery()}
	}

	func send(to device:RemoteDeviceInfo){
		guard !urls.isEmpty, let id=device.id else {return}
		selectedDevice=device
		phase = .connecting(device.name)
		if discoveryRunning{
			manager.stopDeviceDiscovery()
			discoveryRunning=false
		}
		if !manager.startOutgoingTransfer(deviceID:id, delegate:self, urls:urls){
			selectedDevice=nil
			fail("That device is no longer available. Keep Quick Share open and try again.")
		}
	}

	func showQRCode(){
		qrCodeTransferPending=false
		let key=manager.generateQrCodeKey()
		qrCodeURL=URL(string:"https://quickshare.google/qrcode#key=\(key)")
	}

	/// Only drops the key when the user walks away from the sheet. A scan hands
	/// the key to the outgoing connection, which needs it to sign the handshake.
	func dismissQRCode(){
		qrCodeURL=nil
		guard !qrCodeTransferPending else {return}
		manager.clearQrCodeKey()
	}

	func cancel(){
		if let id=selectedDevice?.id{manager.cancelOutgoingTransfer(id:id)}
		cleanup()
		let error=NSError(domain:NSCocoaErrorDomain, code:NSUserCancelledError)
		extensionContext?.cancelRequest(withError:error)
	}

	private func loadItems() async{
		guard let inputItems=extensionContext?.inputItems as? [NSExtensionItem] else{
			fail("Nothing was shared.")
			return
		}
		let providers=inputItems.flatMap{$0.attachments ?? []}
		do{
			for provider in providers{
				if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
				   let value=try await provider.loadItem(forTypeIdentifier:UTType.fileURL.identifier) as? URL{
					urls.append(try copyIntoTemporaryDirectory(value))
				}else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
						 let value=try await provider.loadItem(forTypeIdentifier:UTType.url.identifier) as? URL{
					urls.append(value.isFileURL ? try copyIntoTemporaryDirectory(value) : value)
				}else if let identifier=provider.registeredTypeIdentifiers.first{
					urls.append(try await provider.copyFileRepresentation(forTypeIdentifier:identifier))
				}
			}
			guard !urls.isEmpty else{
				fail("LiftDrop could not read the shared items.")
				return
			}
			itemCount=urls.count
			phase = .choosing
		}catch{
			fail(error.localizedDescription)
		}
	}

	private func fail(_ message:String){
		phase = .failed(message)
	}

	private func copyIntoTemporaryDirectory(_ source:URL) throws -> URL{
		let destination=FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString+"-"+source.lastPathComponent)
		try FileManager.default.copyItem(at:source, to:destination)
		return destination
	}

	private func cleanup(){
		manager.removeShareExtensionDelegate(self)
		if discoveryRunning{
			manager.stopDeviceDiscovery()
			discoveryRunning=false
		}
		qrCodeTransferPending=false
		manager.clearQrCodeKey()
	}
}

extension ShareExtensionModel:ShareExtensionDelegate{
	nonisolated func addDevice(device:RemoteDeviceInfo){
		Task{@MainActor in
			guard !devices.contains(where:{$0.id==device.id}) else {return}
			devices.append(device)
		}
	}

	nonisolated func removeDevice(id:String){
		Task{@MainActor in devices.removeAll(where:{$0.id==id})}
	}

	nonisolated func startTransferWithQrCode(device:RemoteDeviceInfo){
		Task{@MainActor in
			qrCodeTransferPending=true
			qrCodeURL=nil
			send(to:device)
		}
	}

	nonisolated func connectionWasEstablished(pinCode:String){
		Task{@MainActor in phase = .approval(pinCode)}
	}

	nonisolated func connectionFailed(with error:Error){
		Task{@MainActor in fail(transferErrorDescription(error))}
	}

	nonisolated func transferAccepted(){
		Task{@MainActor in phase = .sending(0)}
	}

	nonisolated func transferProgress(progress:Double){
		Task{@MainActor in phase = .sending(progress)}
	}

	nonisolated func transferFinished(){
		Task{@MainActor in
			phase = .complete
			try? await Task.sleep(for:.seconds(0.8))
			cleanup()
			extensionContext?.completeRequest(returningItems:nil)
		}
	}
}

private extension NSItemProvider{
	func loadItem(forTypeIdentifier identifier:String) async throws -> NSSecureCoding?{
		try await withCheckedThrowingContinuation{ continuation in
			loadItem(forTypeIdentifier:identifier, options:nil){ item, error in
				if let error{continuation.resume(throwing:error)}
				else{continuation.resume(returning:item)}
			}
		}
	}

	func copyFileRepresentation(forTypeIdentifier identifier:String) async throws -> URL{
		try await withCheckedThrowingContinuation{ continuation in
			loadFileRepresentation(forTypeIdentifier:identifier){ url, error in
				if let error{continuation.resume(throwing:error)}
				else if let url{
					do{
						let destination=FileManager.default.temporaryDirectory
							.appendingPathComponent(UUID().uuidString+"-"+url.lastPathComponent)
						try FileManager.default.copyItem(at:url, to:destination)
						continuation.resume(returning:destination)
					}catch{
						continuation.resume(throwing:error)
					}
				}
				else{continuation.resume(throwing:CocoaError(.fileNoSuchFile))}
			}
		}
	}
}
