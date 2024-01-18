echo ◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺
echo ◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺
echo ◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺
echo
echo Let\'s build your initialization code!
echo 
echo ◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺
echo ◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺
echo ◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺◹◺
echo
echo
echo
# get contract type
echo Contract type:
read contract_type
echo
# get name
echo Name:
read name
echo
# get symbol
echo Symbol:
read symbol
echo
# get personalization
echo Personalization:
read personalization
if [ -z $personalization ]
then
    personalization=\"\"
fi
echo
# get royalty percentage
echo 'Royalty percentage (basis)':
read perc
echo
# get royalty recipient
echo Royalty recipient:
read recp
echo
# get deployer address
echo Deployer address:
read deployer
echo
# get admins
echo 'Admins (array format):'
read admins
if [ -z $admins ]
then
    admins=[]
fi
echo
# get if story enabled
echo 'Story enabled (true/false):'
read story_enabled
echo
# get blocklist registry
echo BlockList Registry:
read blocklist_registry
echo
# build command
echo 
echo 
echo 🚀 init code below! 🚀
echo
echo
if [ contract_type = 'ERC1155TL' ]
then
    echo $(cast calldata "initialize(string,string,string,address,uint256,address,address[],bool,address)" $name $symbol $personalization $recp $perc $deployer $admins $story_enabled $blocklist_registry)
else
    echo $(cast calldata "initialize(string,string,string,address,uint256,address,address[],bool,address,address)" $name $symbol $personalization $recp $perc $deployer $admins $story_enabled $blocklist_registry 0x05060a6dade0ab0a9f762976f03634ff9a14e3a3)
fi
echo 
echo 
echo 🚀 SUCCESS 🚀