import { action, observable } from "mobx";
import getWeb3 from '../getWeb3';
import Web3 from 'web3';
import tokens from "../assets/tokens.json";
import GetBalancerAbi from "../abis/BalanceChecker.json"
const BN = require('bignumber.js');

class Web3Store {
  @observable web3 = {};
  @observable defaultAccount = '';
  getWeb3Promise = null;
  @observable loading = true;
  @observable errors = [];
  @observable userTokens = [];
  @observable explorerUrl = '';
  @observable startedUrl = window.location.hash
  @observable mainSymbol = '';

  proxyGetBalancerAddress =  process.env.REACT_APP_PROXY_GETBALANCER

  constructor(rootStore) {
    
    this.getWeb3Promise = getWeb3().then(async (web3Config) => {
      const {web3Instance, defaultAccount} = web3Config;
      this.defaultAccount = defaultAccount;
      this.web3 = new Web3(web3Instance.currentProvider); 
      this.getUserTokens(web3Config)
      this.setExplorerUrl(web3Config.explorerUrl)
      this.setMainSymbol(web3Config.mainSymbol)
      console.log('web3 loaded')
    }).catch((e) => {
      console.error(e,'web3 not loaded')
      this.errors.push(e.message)
    })
  }
  @action
  setExplorerUrl(url){
    this.explorerUrl = url
  }
  @action
  setStartedUrl(url){
    this.startedUrl = url;
  }
  @action
  setMainSymbol(symbol){
    this.mainSymbol = symbol;
  }
  async getUserTokens({trustApiName, defaultAccount}) {

    const getbalancer = new this.web3.eth.Contract(GetBalancerAbi, this.proxyGetBalancerAddress);
    console.log(this.proxyGetBalancerAddress)
    var ethBalance = await this.web3.eth.getBalance(defaultAccount); //Will give value in.
    ethBalance = this.web3.utils.fromWei(ethBalance);
    ethBalance = new BN(ethBalance).toFormat(3)
    console.log(ethBalance)

    let husd_addr = '0x0298c2b32eae4da002a15f36fdf7615bea3da047';
    let husd_balance = await getbalancer.methods.tokenBalance(defaultAccount, husd_addr).call();
    //let result = await getbalancer.methods.tokenBalance(defaultAccount, '0x0000000000000000000000000000000000000000').call();
    let addresses = [];
    let addressmap = {};
    for(let token in tokens){
      addresses.push(tokens[token].address)
      addressmap[tokens[token].address] = tokens[token];
    }
   const decimals = Number(addressmap[husd_addr].decimal)
   husd_balance = new BN(husd_balance).div(new BN(10).pow(decimals)).toString(10)
   console.log(husd_balance)
   let result = await getbalancer.methods.balances([defaultAccount], addresses).call();
   for(let i in result){
      if(parseInt(result[i]) > 0){
        let decimal = Number(tokens[i].decimal)
        let balance = new BN(result[i]).div(new BN(10).pow(decimal)).toFormat(3)
        let value = tokens[i].address
        let label = tokens[i].symbol + '-' + value + '(' + balance + ')'
        if(value === '0x0000000000000000000000000000000000000000')
        {
          value = '0x000000000000000000000000000000000000bEEF'
          label = 'HT - HECO Native Currency'
        }
        
        this.userTokens.push({
          label: label,
          value: value
        });
      }
   } 
   this.loading = false
   console.log(result);
    // window.fetch(`https://${trustApiName}.trustwalletapp.com/tokens?address=${defaultAccount}`).then((res) => {
    //   return res.json()
    // }).then((res) => {
    //   let tokens = res.docs.map(({contract}) => {
    //     const {address, symbol} = contract;
    //     return {label: `${symbol} - ${address}`, value: address}
    //   })
    //   tokens.unshift({
    //     value: '0x000000000000000000000000000000000000bEEF',
    //     label: "ETH - Ethereum Native Currency"
    //   })
    //   this.userTokens = tokens;
    //   this.loading = false;
    // }).catch((e) => {
    //   this.loading = false;
    //   console.error(e);
    // })
  }

}

export default Web3Store;