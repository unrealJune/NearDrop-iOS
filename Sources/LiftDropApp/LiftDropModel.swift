import CoreTransferable
import Foundation
import NearbyShareCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class LiftDropModel:NSObject, ObservableObject{
	enum Phase:Equatable{
		case ready
		case connecting(String)
		case awaitingApproval(String, pin:String)
		case transferring(String, progress:Double)
		case complete(String)
		case failed(String)
	}

	struct IncomingRequest:Identifiable{
		let id:String
		let device:RemoteDeviceInfo
		let transfer:TransferMetadata
	}

	struct ReceivedItem:Identifiable{
		let id=UUID()
		let url:URL
		let deviceName:String
	}

	struct ReceivedLink:Identifiable{
		let id=UUID()
		let url:URL
		let deviceName:String
	}

	@Published private(set) var devices:[RemoteDeviceInfo]=[]
	@Published private(set) var phase=Phase.ready
	@Published private(set) var isAvailable=false
	@Published private(set) var receivedItems:[ReceivedItem]=[]
	@Published private(set) var isPreparingItems=false
	@Published var incomingRequest:IncomingRequest?
	@Published var receivedLink:ReceivedLink?
	@Published var selectedURLs:[URL]=[]
	@Published var qrCodeURL:URL?

	private let manager=NearbyConnectionManager.shared
	private var discoveryRunning=false
	private var selectedDevice:RemoteDeviceInfo?
	private var securityScopedURLs:[URL]=[]
	private var activeIncomingTransferID:String?
	private var qrCodeTransferPending=false
	private var photoLoadTask:Task<Void, Never>?

	override init(){
		super.init()
		StagedMedia.removeAll()
		manager.mainAppDelegate=self
		manager.receivedContentHandler=self
		manager.localDeviceName=UIDevice.current.name
		switch UIDevice.current.userInterfaceIdiom{
		case .pad:
			manager.localDeviceType = .tablet
		default:
			manager.localDeviceType = .phone
		}
	}

	func becomeActive(){
		guard !isAvailable else {return}
		isAvailable=true
		manager.becomeVisible()
		manager.addShareExtensionDelegate(self)
		manager.startDeviceDiscovery()
		discoveryRunning=true
	}

	func resignActive(){
		guard isAvailable else {return}
		isAvailable=false
		if discoveryRunning{
			manager.stopDeviceDiscovery()
			discoveryRunning=false
		}
		manager.removeShareExtensionDelegate(self)
		manager.resignVisibility()
		devices.removeAll()
	}

	func choose(urls:[URL]){
		releaseSelection()
		selectedURLs=urls
		securityScopedURLs=urls.filter{$0.startAccessingSecurityScopedResource()}
		phase = .ready
	}

	/// Photos are exported into a staging directory first because the protocol
	/// needs real files with a known size before the transfer starts.
	func choose(photos items:[PhotosPickerItem]){
		guard !items.isEmpty else {return}
		releaseSelection()
		phase = .ready
		isPreparingItems=true
		photoLoadTask=Task{
			var urls:[URL]=[]
			for item in items{
				if Task.isCancelled {return}
				// Items that fail to export are skipped; the header count shows what will be sent.
				if let media=try? await item.loadTransferable(type:StagedMedia.self){
					urls.append(media.url)
				}
			}
			if Task.isCancelled {return}
			isPreparingItems=false
			photoLoadTask=nil
			selectedURLs=urls
			if urls.isEmpty{
				phase = .failed("LiftDrop could not read the selected photos. If they are stored in iCloud, check your connection and try again.")
			}
		}
	}

	func send(to device:RemoteDeviceInfo){
		guard let id=device.id, !selectedURLs.isEmpty else {return}
		selectedDevice=device
		phase = .connecting(device.name)
		if !manager.startOutgoingTransfer(deviceID: id, delegate: self, urls: selectedURLs){
			selectedDevice=nil
			phase = .failed("That device is no longer available. Keep Quick Share open and try again.")
		}
	}

	func cancelTransfer(){
		if let id=selectedDevice?.id{
			manager.cancelOutgoingTransfer(id: id)
		}
		finishSending()
		phase = .ready
	}

	func acceptIncoming(){
		guard let request=incomingRequest else {return}
		activeIncomingTransferID=request.id
		manager.submitUserConsent(transferID: request.id, accept: true)
		phase = .transferring(request.device.name, progress: 0)
		incomingRequest=nil
	}

	func declineIncoming(){
		guard let request=incomingRequest else {return}
		manager.submitUserConsent(transferID: request.id, accept: false)
		activeIncomingTransferID=nil
		incomingRequest=nil
		phase = .ready
	}

	func showQRCode(){
		qrCodeTransferPending=false
		let key=manager.generateQrCodeKey()
		qrCodeURL=URL(string: "https://quickshare.google/qrcode#key=\(key)")
	}

	/// Only drops the key when the user walks away from the sheet. A scan hands
	/// the key to the outgoing connection, which needs it to sign the handshake.
	func dismissQRCode(){
		qrCodeURL=nil
		guard !qrCodeTransferPending else {return}
		manager.clearQrCodeKey()
	}

	func reset(){
		phase = .ready
		selectedDevice=nil
		qrCodeTransferPending=false
		manager.clearQrCodeKey()
		releaseSelection()
	}

	private func finishSending(){
		releaseSecurityScopedResources()
		selectedDevice=nil
		qrCodeTransferPending=false
		manager.clearQrCodeKey()
	}

	private func releaseSecurityScopedResources(){
		securityScopedURLs.forEach{$0.stopAccessingSecurityScopedResource()}
		securityScopedURLs.removeAll()
	}

	private func releaseSelection(){
		photoLoadTask?.cancel()
		photoLoadTask=nil
		isPreparingItems=false
		releaseSecurityScopedResources()
		selectedURLs=[]
		StagedMedia.removeAll()
	}
}

/// A photo or video exported from the photo library into the app's temporary
/// directory, keeping the name Photos gives it so the receiver sees a
/// meaningful file name.
struct StagedMedia:Transferable{
	let url:URL

	static var transferRepresentation:some TransferRepresentation{
		// Images first so a Live Photo is sent as its still photo.
		FileRepresentation(importedContentType:.image){ received in
			StagedMedia(url:try stage(received.file, fallbackName:"Photo"))
		}
		FileRepresentation(importedContentType:.movie){ received in
			StagedMedia(url:try stage(received.file, fallbackName:"Video"))
		}
	}

	private static var root:URL{
		FileManager.default.temporaryDirectory.appendingPathComponent("Outgoing", isDirectory:true)
	}

	static func removeAll(){
		try? FileManager.default.removeItem(at:root)
	}

	/// Each file gets its own directory so identical names never collide.
	private static func stage(_ source:URL, fallbackName:String) throws -> URL{
		let directory=root.appendingPathComponent(UUID().uuidString, isDirectory:true)
		try FileManager.default.createDirectory(at:directory, withIntermediateDirectories:true)
		let baseName=source.deletingPathExtension().lastPathComponent
		let name=UUID(uuidString:baseName)==nil ? source.lastPathComponent : fallbackName+"."+source.pathExtension
		let destination=directory.appendingPathComponent(name)
		try FileManager.default.copyItem(at:source, to:destination)
		return destination
	}
}

extension LiftDropModel:MainAppDelegate{
	nonisolated func obtainUserConsent(for transfer:TransferMetadata, from device:RemoteDeviceInfo){
		Task{@MainActor in
			incomingRequest=IncomingRequest(id: transfer.id, device: device, transfer: transfer)
		}
	}

	nonisolated func incomingTransfer(id:String, progress:Double){
		Task{@MainActor in
			if case let .transferring(name, _)=phase{
				phase = .transferring(name, progress: progress)
			}
		}
	}

	nonisolated func incomingTransfer(id:String, didFinishWith error:Error?){
		Task{@MainActor in
			guard activeIncomingTransferID==id else{return}
			activeIncomingTransferID=nil
			if let error{
				phase = .failed(transferErrorDescription(error))
			}else{
				phase = .complete("Received")
			}
		}
	}
}

extension LiftDropModel:ReceivedContentHandler{
	nonisolated func destinationURL(for file:FileMetadata) throws -> URL{
		let documents=try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		let received=documents.appendingPathComponent("Received", isDirectory: true)
		try FileManager.default.createDirectory(at: received, withIntermediateDirectories: true)
		return received.appendingPathComponent(file.name)
	}

	nonisolated func didReceiveFile(at url:URL, from device:RemoteDeviceInfo){
		Task{@MainActor in
			receivedItems.insert(ReceivedItem(url: url, deviceName: device.name), at: 0)
		}
	}

	nonisolated func didReceiveURL(_ url:URL, from device:RemoteDeviceInfo){
		Task{@MainActor in
			receivedLink=ReceivedLink(url: url, deviceName: device.name)
		}
	}
}

extension LiftDropModel:ShareExtensionDelegate{
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
			send(to: device)
		}
	}

	nonisolated func connectionWasEstablished(pinCode:String){
		Task{@MainActor in
			phase = .awaitingApproval(selectedDevice?.name ?? "Nearby device", pin: pinCode)
		}
	}

	nonisolated func connectionFailed(with error:Error){
		Task{@MainActor in
			finishSending()
			phase = .failed(transferErrorDescription(error))
		}
	}

	nonisolated func transferAccepted(){
		Task{@MainActor in
			phase = .transferring(selectedDevice?.name ?? "Nearby device", progress: 0)
		}
	}

	nonisolated func transferProgress(progress:Double){
		Task{@MainActor in
			phase = .transferring(selectedDevice?.name ?? "Nearby device", progress: progress)
		}
	}

	nonisolated func transferFinished(){
		Task{@MainActor in
			let name=selectedDevice?.name ?? "Nearby device"
			finishSending()
			phase = .complete("Sent to \(name)")
		}
	}
}
