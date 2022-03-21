import ClaimNFT from 0xClaimNFT
import IClaimNFT from 0xIClaimNFT

// Claim owner requests a claim metadata reveal.

transaction(id: UInt64){
    prepare(signer: AuthAccount) {
        let collectionRef = signer.borrow<&ClaimNFT.Collection>(from: ClaimNFT.CollectionStoragePath)!
        collectionRef.borrowClaimNFT(id: id)!.reveal()
    }
}