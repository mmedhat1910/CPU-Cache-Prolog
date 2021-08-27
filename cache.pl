:- style_check(-discontiguous).

%general

convertBinToDec(Bin,Dec):-
    convertHelper(Bin,0,0,Dec).
    
convertHelper(0,_,Acc,Acc).
convertHelper(Bin, P ,Acc, Dec ):-
    Bin > 0,
    LSB is Bin mod 10,
    Rest is Bin //10,
    P1 is P+1,
    NewAcc is Acc + (2**P)*LSB,
    convertHelper(Rest, P1, NewAcc , Dec ).


replaceIthItem(_,[],_,[]).
replaceIthItem(X,[_|T],0,[X|T]).
replaceIthItem(X, [H|T], I, [H|T2]):-
    I>0,
    I2 is I-1,
    replaceIthItem(X,T,I2,T2).


splitEvery(_,[],[]).
splitEvery(N,[H|T],Res):-
	reverse([H|T],[RevH|RevT]),
	splitEvery(N,RevT,[[RevH]],Res).
	
splitEvery(_,[],Acc,Acc).
splitEvery(N,[H|T],[X|Y],Res):-
	length(X,N),
	splitEvery(N,T,[[H],X|Y],Res).
splitEvery(N,[H|T],[X|Y],Res):-
	length(X,M),
	M\=N,
	append([H],X,NewX),
	splitEvery(N,T,[NewX|Y],Res).


logBase2(1, 0).
logBase2(Num,Res):-
    0 is Num mod 2,
    Num > 1,
    Num1 is Num/2,
    logBase2(Num1, Res1),
    Res is Res1+1.
logBase2(Num,Res):-
    1 is Num mod 2,
    Num1 is Num+1,
    Num > 1,
    Num2 is Num1/2,
    logBase2(Num2, Res1),
    Res is Res1+1.


getNumBits(_,fullyAssoc,_,0).
getNumBits(NumOfSets, setAssoc,_,NumBits):- 
    logBase2(NumOfSets,NumBits).
getNumBits(_,directMap,Cache,NumBits):-
    length(Cache,L),
    logBase2(L,NumBits).

 
fillZeros(String, 0, String).
fillZeros(String, N, R):-
    N>0,
    string_concat('0', String, NewString),
    N1 is N-1,
    fillZeros(NewString,N1,R).


%Component_1_directMapping

getDataFromCache(StringAddress,Cache,Data,0,directMap,BitsNum):-
	string_length(StringAddress,Len),
	X is Len - BitsNum,
	sub_string(StringAddress,X,_,0,StringIndex),
	atom_number(StringIndex,NumIndex),
	convertBinToDec(NumIndex,DecIndex),
	sub_string(StringAddress,0,_,BitsNum,StringTag),
	nth0(DecIndex,Cache,item(tag(StringTag),data(Data),1,_)).


convertAddress(Bin,BitsNum,Tag,Idx,directMap):-
	atom_number(StringAddress,Bin),
	string_length(StringAddress,Length),
	Y is 6- Length,
	fillZeros(StringAddress,Y,NewAddress),
	X is 6 - BitsNum,
	sub_string(NewAddress,0,_,BitsNum,StringTag),
	sub_string(NewAddress,X,_,0,StringIndex),
    atom_number(StringTag,Tag),
    atom_number(StringIndex,Idx).
	


%Component_2_setAssociative

getDataFromCache(StringAddress,Cache,Data,HopsNum,setAssoc,SetsNum):-
	getNumBits(SetsNum,setAssoc,_,BitsNum),
	string_length(StringAddress,Len),
	X is Len-BitsNum,
	sub_string(StringAddress,0,_,BitsNum,Tag),
	sub_string(StringAddress,X,_,0,StringIndex),
	atom_number(StringIndex,BinIndex),
	convertBinToDec(BinIndex,NumIndex),
	getSet(Cache,NumIndex,SetsNum,SetList),
	checkSet(SetList,Tag,Data,HopsNum).
	
getSet(Cache,NumIndex,SetsNum,SetList):-
	length(Cache,Length),
	NumOfValues is Length//(SetsNum),
	Start is NumIndex*NumOfValues,
	End is Start+NumOfValues,
	getValue(Cache,Start,End,SetList).

getValue(_,Start,Start,[]).
getValue(Cache,Start,End,[H|T]):-
    Start<End,
    nth0(Start,Cache, H),
    Start1 is Start +1,
    getValue(Cache,Start1,End,T).

checkSet([item(tag(Tag1),data(Data),1,_)|_],Tag2,Data,0):-
	atom_number(Tag1,Tag),
	atom_number(Tag2,Tag).
checkSet([_|T],Tag,Data,HopsNum):-
	checkSet(T,Tag,Data,HopsNum1),
	HopsNum is HopsNum1 +1 .


convertAddress(Bin,SetsNum,Tag,Idx,setAssoc):-
    getNumBits(SetsNum, setAssoc, _, BitsNum),
    atom_number(StringAddress,Bin),
    sub_string(StringAddress,0,_,BitsNum,StringTag),
    string_length(StringAddress,Length),
    X is Length - BitsNum,
	X>0,
    sub_string(StringAddress,X,_,0,StringIndex),
    atom_number(StringTag,Tag),
    atom_number(StringIndex,Idx).
convertAddress(Bin,SetsNum,0,Bin,setAssoc):-
    getNumBits(SetsNum, setAssoc, _, BitsNum),
    atom_number(StringAddress,Bin),
    string_length(StringAddress,Length),
    X is Length - BitsNum,
    X=0.
convertAddress(Bin,1,Bin,0,setAssoc).


%Component_3_ReplacingBlocks

replaceInCache(Tag,Idx,Mem,OldCache,NewCache,ItemData,directMap,BitsNum):- 
    getEffectiveAddress(Tag, Idx, directMap, BitsNum, StringAddress),
    atom_number(StringAddress, BinAddressNum),
    convertBinToDec(BinAddressNum, Address),
    nth0(Address, Mem, ItemData),
    getFullTag(Tag, directMap, BitsNum, FullTag),
    NewItem = item(tag(FullTag), data(ItemData), 1, 0),
    convertBinToDec(Idx, ReplaceIdx),
    replaceIthItem(NewItem,OldCache, ReplaceIdx, NewCache).


replaceInCache(Tag,_,Mem,OldCache,NewCache,ItemData,fullyAssoc, _):-
    convertBinToDec(Tag, Address),
    nth0(Address, Mem, ItemData),
    getFullTag(Tag, fullyAssoc, _, FullTag),
    NewItem = item(tag(FullTag), data(ItemData),1,0),
    getMaxOrder(OldCache,Max),
    (
        firstNth0(ReplaceIdx, OldCache, item(_,_,0,_));
        ( 
            \+ nth0(_, OldCache,item(_,_,0,_)),
            nth0(ReplaceIdx,OldCache,item(_,_,1,Max))
        )
    ),
    incrementOrders(OldCache, UpdatedOldCache),
    replaceIthItem(NewItem, UpdatedOldCache, ReplaceIdx, NewCache).
	

replaceInCache(Tag,Idx,Mem,OldCache,NewCache,ItemData, setAssoc,SetsNum):- 
    getNumBits(SetsNum, setAssoc,_,BitsNum),
    getEffectiveAddress(Tag, Idx, setAssoc, BitsNum, StringAddress),
    atom_number(StringAddress, BinAddressNum),
    convertBinToDec(BinAddressNum, Address),
    nth0(Address, Mem, ItemData),
    getFullTag(Tag, setAssoc, BitsNum, FullTag),
    NewItem = item(tag(FullTag), data(ItemData), 1, 0),
    length(OldCache, L),
    SetSize is L / SetsNum,
    splitEvery(SetSize,OldCache,CacheSets),
    convertBinToDec(Idx, SetIndex),
    nth0(SetIndex,CacheSets, Set),
    getMaxOrder(Set,Max),
    (
       
        firstNth0(ReplaceIdx, Set, item(_,_,0,_));
        (
           
            \+ nth0(_, Set,item(_,_,0,_)),
            nth0(ReplaceIdx,Set,item(_,_,1,Max))
        )
    ),
    incrementOrders(Set, UpdatedSet),
    replaceIthItem(NewItem, UpdatedSet, ReplaceIdx, NewSet),
    replaceIthItem(NewSet,CacheSets, SetIndex, UpdatedCacheSets),
    appendSplitted(UpdatedCacheSets, NewCache).


appendSplitted([], []).
appendSplitted([H],H).
appendSplitted([H1, H2|T], L):-
    is_list(H1),
    is_list(H2),
    append(H1, H2, Heads),
    appendSplitted([Heads|T], L).
    
firstNth0(Index, List, Item):- 
    firstNth0(0, Index, List, Item).

firstNth0(Acc, Acc, [Item|_], Item).
firstNth0(Acc, Index, [H|T], Item):-
    Item \= H,
    NewAcc is Acc +1,
    firstNth0(NewAcc, Index,T, Item).

incrementOrders([],[]).
incrementOrders([item(Tag, Data, 1, Order)|T], [item(Tag, Data, 1, NewOrder)|T2]):-
    NewOrder is Order +1,
    incrementOrders(T,T2).
incrementOrders([item(Tag, Data, 0, Order)|T], [item(Tag, Data, 0, Order)|T2]):-
    incrementOrders(T,T2).

max(Num1, Num2, Num1):- Num1 >= Num2.
max(Num1, Num2, Num2):- Num1 < Num2.

getMaxOrder([], 0).
getMaxOrder([item(_, _, _, Order)|T], Max):-
    getMaxOrder(T, MaxRest),
    max(Order,MaxRest, Max).

getFullTag(Tag, fullyAssoc, _, FullTag):-
    atom_number(TagString, Tag),
    string_length(TagString,TagLength),
    Zeros is 6 - TagLength,
    fillZeros(Tag, Zeros, FullTag).
getFullTag(Tag, Type, BitsNum, FullTag):-
    Type \= fullyAssoc,
    atom_number(TagString, Tag),
    string_length(TagString,TagLength),
    Zeros is 6 -BitsNum -  TagLength,
    fillZeros(Tag, Zeros, FullTag).

getFullIdx(Idx, Type, BitsNum, FullIdx):-
    Type \= fullyAssoc,
    atom_number(IdxString, Idx),
    string_length(IdxString,IdxLength),
    IdxZeros is BitsNum - IdxLength,
    fillZeros(Idx, IdxZeros, FullIdx).

getEffectiveAddress(Tag, Idx, CacheType, BitsNum, EffAddress):-
    getFullTag(Tag, CacheType, BitsNum ,FullTag), 
    getFullIdx(Idx, CacheType, BitsNum, FullIdx),
    string_concat(FullTag, FullIdx, EffAddress).


%Component_4_SetAssociative

getDataFromCache(StringAddress,[item(tag(Tag),data(Data),ValidBit,_)|_],Data,HopsNum,fullyAssoc,_):-
    atom_number(StringAddress, AddressNum),
    atom_number(Tag,TagNum),
	TagNum=AddressNum,
	ValidBit\=0,
	HopsNum=0 .
	
getDataFromCache(StringAddress,[item(tag(Tag),data(_),_,_)|T],Data,HopsNum,fullyAssoc,_):-
	atom_number(StringAddress, AddressNum),
    atom_number(Tag,TagNum),
	TagNum\=AddressNum,
	getDataFromCache(StringAddress,T,Data,Hops,fullyAssoc,_),
	HopsNum is Hops +1 .

convertAddress(Bin,_,Bin,_,fullyAssoc).


%previously_implemented
	
getData(StringAddress,OldCache,Mem,NewCache,Data,HopsNum,Type,BitsNum,hit):-
    getDataFromCache(StringAddress,OldCache,Data,HopsNum,Type,BitsNum),
    NewCache = OldCache.

getData(StringAddress,OldCache,Mem,NewCache,Data,HopsNum,Type,BitsNum,miss):-
    \+getDataFromCache(StringAddress,OldCache,Data,HopsNum,Type,BitsNum),
    atom_number(StringAddress,Address),
    convertAddress(Address,BitsNum,Tag,Idx,Type),
    replaceInCache(Tag,Idx,Mem,OldCache,NewCache,Data,Type,BitsNum).


runProgram([],OldCache,_,OldCache,[],[],Type,_).
runProgram([Address|AdressList],OldCache,Mem,FinalCache,[Data|OutputDataList],[Status|StatusList],Type,NumOfSets):-
	getNumBits(NumOfSets,Type,OldCache,BitsNum),
	(Type = setAssoc, Num = NumOfSets;( Type \= setAssoc, Num = BitsNum)),
	getData(Address,OldCache,Mem,NewCache,Data,HopsNum,Type,Num,Status),runProgram(AdressList,NewCache,Mem,FinalCache,OutputDataList,StatusList,Type,NumOfSets).
