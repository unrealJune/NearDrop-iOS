import Foundation
import NearbyShareCore

func transferErrorDescription(_ error:Error)->String{
	guard let nearbyError=error as? NearbyError else{return error.localizedDescription}
	switch nearbyError{
	case let .protocolError(message):
		return "The devices stopped speaking the same transfer protocol. \(message)"
	case .requiredFieldMissing:
		return "The other device sent an incomplete transfer request."
	case .ukey2:
		return "LiftDrop could not establish an encrypted connection."
	case .inputOutput:
		return "LiftDrop could not read or write one of the files."
	case let .canceled(reason):
		switch reason{
		case .userRejected:return "The transfer was declined on the other device."
		case .userCanceled:return "The transfer was canceled."
		case .notEnoughSpace:return "The other device does not have enough storage."
		case .unsupportedType:return "The other device does not support this item type."
		case .timedOut:return "The other device did not respond in time."
		}
	}
}
