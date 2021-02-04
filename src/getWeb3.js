import Web3 from 'web3'
async function getWeb3NetworkResult(netId){
    let netIdName, trustApiName, explorerUrl, mainSymbol,results;
            console.log('netId', netId);
            switch (parseInt(netId)) {
              case 1:
                netIdName = 'Foundation'
                trustApiName = 'api'
                explorerUrl = 'https://etherscan.io'
                console.log('This is Foundation', netId)
                mainSymbol = 'ETH'
                break;
              case 3:
                netIdName = 'Ropsten'
                trustApiName = 'ropsten'
                explorerUrl = 'https://ropsten.etherscan.io'
                console.log('This is Ropsten', netId)
                mainSymbol = 'ETH'
                break;
              case 4:
                netIdName = 'Rinkeby'
                trustApiName = 'rinkeby'
                explorerUrl = 'https://rinkeby.etherscan.io'
                console.log('This is Rinkeby', netId)
                mainSymbol = 'ETH'
                break;
              case 42:
                netIdName = 'Kovan'
                trustApiName = 'kovan'
                explorerUrl = 'https://kovan.etherscan.io'
                console.log('This is Kovan', netId)
                mainSymbol = 'ETH'
                break;
              case 99:
                netIdName = 'POA Core'
                trustApiName = 'poa'
                explorerUrl = 'https://poaexplorer.com'
                console.log('This is Core', netId)
                mainSymbol = 'ETH'
                break;
              case 77:
                netIdName = 'POA Sokol'
                trustApiName = 'https://trust-sokol.herokuapp.com'
                explorerUrl = 'https://sokol.poaexplorer.com'
                console.log('This is Sokol', netId)
                mainSymbol = 'ETH'
                break;
              case 128:
                netIdName = "HECO Mainet"
                trustApiName = "HECO"
                explorerUrl = "https://scan.hecochain.com"
                mainSymbol = 'HT'
                break
              case 256:
                netIdName = "HECO Testnet"
                trustApiName = "HECOTest"
                explorerUrl = "https://scan-testnet.hecochain.com"
                mainSymbol = 'HT'
                break
              default:
                netIdName = 'Unknown'
                console.log('This is an unknown network.', netId)
                mainSymbol = 'ETH'
            }
            document.title = `${netIdName} - MultiSender dApp`
            const accounts = await window.web3.eth.getAccounts()
            var defaultAccount = accounts[0] || null;
            if(defaultAccount === null){
              return false
            }
            results = {
              web3Instance: window.web3,
              netIdName,
              netId,
              injectedWeb3: true,
              defaultAccount,
              trustApiName,
              explorerUrl,
              mainSymbol
            }
            console.log(results)
        return results
}
let getWeb3 = () => {
  return new Promise(function (resolve, reject) {
    // Wait for loading completion to avoid race conditions with web3 injection timing.
    window.addEventListener('load', async function () {
      var results
        // Use Mist/MetaMask's provider.
      //var web3 = window.web3
      if(window.web3){
        //web3 = new window.Web3(web3.currentProvider)
        let ua = window.navigator.userAgent
        if(ua.toLowerCase().indexOf('bitkeep') === -1){
          if (window.ethereum) {
            window.web3 = new Web3(window.ethereum) 
            await window.ethereum.enable()
          } else if (window.web3) {
            window.web3 = new Web3(window.web3.currentProvider)
          } 
        }
        else{
          if (window.web3) {
            window.web3 = new Web3(window.web3.currentProvider)
          } else if (window.ethereum) {
            window.web3 = new Web3(window.ethereum) 
            await window.ethereum.enable() 
          } 
        }
        if(window.web3.version && window.web3.version.getNetwork){
          window.web3.version.getNetwork((err, netId) => {
            results = getWeb3NetworkResult(netId)
            if(!results){
              reject({message: 'Please unlock your metamask and refresh the page'})
            }
            resolve(results)
          })
        }
        else{
          if(window.web3.eth.net)
          {
            var networkId = await window.web3.eth.net.getId()
            results = await getWeb3NetworkResult(networkId)
            if(!results){
              reject({message: 'Please unlock your metamask and refresh the page'})
            }
            resolve(results)
          } 
        }
        console.log('Injected web3 detected.');

      } else {
        // Fallback to localhost if no web3 injection.
        const errorMsg = `Metamask is not installed. Please go to
        https://metamask.io and return to this page after you installed it`
        reject({message: errorMsg})
        console.log('No web3 instance injected, using Local web3.');
        console.error('Metamask not found'); 
      }
    })
  })
}

export default getWeb3
