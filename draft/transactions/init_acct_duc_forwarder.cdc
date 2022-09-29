import FungibleToken from 0xFungibleToken
import TokenForwarding from 0xTokenForwarding

transaction(receiver: Address) {

  prepare(acct: AuthAccount) {

    // recipient of forwarded DUC is mock-dapper account
    let ducReceiverCap = getAccount(receiver)
        .getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)!

    let forwarderVault <- TokenForwarding.createNewForwarder(recipient: ducReceiverCap)
    acct.save(<-forwarderVault, to: /storage/dapperUtilityCoinForwarder)

    if acct.getCapability(/public/dapperUtilityCoinReceiver).check<&{FungibleToken.Receiver}>() {
        acct.unlink(/public/dapperUtilityCoinReceiver)
    }
    acct.link<&{FungibleToken.Receiver}>(
        /public/dapperUtilityCoinReceiver,
        target: /storage/dapperUtilityCoinForwarder
    )
  }

}
