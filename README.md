Case Database Viewer
==============

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) ![This script was last tested in Nuix 8.6](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-8.6-green.svg)

View the GitHub project [here](https://github.com/Nuix/Named-Entity-Validation) or download the latest release [here](https://github.com/Nuix/Named-Entity-Validation/releases).

# Overview

This project was conceptualised as a way of adding a convenient way for validating named entities.

Most captures are so generic in nature (i.e. 8 digits) yet those entities have a way of checking that those 8 digits are valid.

One of the largest reasons people may avoid Nuix entity wrappers is because of the greedy way they are captured with a requirement to validate these entities outside of Nuix.

It could be used in replacement to the built in Named Entities and will in fact generate the same results.

## It's a bit of fun ok?
For now this is something I whipped up out of inspiration. It's not fully fleshed out and it's not entirely user friendly as I'd like.

If you like it - let me (Cameron Stiller) know!

Got issues - raise one please!

It may take me a while to get back to any issues, this project is concept art :)

I would love to see this project completely and utterly maintained by those passionate enough to use it.

If there is an entity you define consider raising an issue with your steps and it'll be included in the next version for all to benefit.

When there is enough in here and verified as being used regularly we can petition Nuix to bundle with these in some way, perhaps even as this tool describes.


# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

# Usage

## Preparing cases for use

This is a two-stage process. 

### Verify your entities are installed correctly and available
1. Create or open an existing case
2. Run this script from the menu.
3. Open up Scripts -> Script console 
4. If prompted to update the script please do so, this will ensure workers can find your definitions for validation.
5. As it loads you'll see the entities being checked.
6. This will also copy the images and titles into the case for Nuix to discover them in the various menus they are displayed.

### Apply the worker side script
1. Browse to where you installed this script
2. Open Named Entity Validation.nuixscript
3. Open runme.rb in a text editor
4. Edit the first few lines to appropriately point to the helper pack JSON file
5. Edit the first few lines to select a group of entities or singular entities to check for.
6. Copy the contents to your worker side script tab
7. Wait for the magic to run...
8. See your verified entities now inside Nuix!

## How does it work?
Many entities (especially old ones) were designed to be easily validated at the client side with mechanical (crank driven believe it or not!) which were then translated to basic machine language processes.
Nowadays things like ID's can be validated quicker at the server and may not follow any particular pattern.... If you have one of these types, this isn't for you...

For entities with known algorithms to check, things like a LUHN validator or tax number, health insurance many are out there... they usually operate on a few easily described steps.
This project works on that concept. The steps are all generalized so any algorithm can use them.

For example an Australian Business Number is publicly described on their website as having a [specific format and algorithm|https://abr.business.gov.au/Help/AbnFormat]:

Those steps could be written as:
1. Split the characters

```json
  {
    "method": "splitIntoChunks",
    "params": [ "" ]
  },
```

2. Remove any spaces (ABN's rarely are displayed with anything but spaces separating groups)

```json
  {
    "method": "removeElements",
    "params": [ " " ]
  },
```
  
3. Convert those chars to single digits (could have also used substitueArray)

```json
  {
    "method": "mapIntArrayToStringArray",
    "params": [ ]
  },
```
  
4. Negate one from the first position in the existing array of size 11

```json
  {
    "method": "addArray",
    "params": [
      {
        "11": [ -1 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ]
      }
    ]
  },
```
  
5. Apply a weight based on position in the existing array of size 11

```json
  {
    "method": "applyWeight",
    "params": [
      {
        "11": [ 10 , 1 , 3 , 5 , 7 , 9 , 11 , 13, 15, 17, 19 ]
      }
    ]
  },
```

6. Sum up the array of the result

```json
  {
    "method": "sumArray"
  },
```
  
6. Apply a math modulus of 89

```json
  {
    "method": "modBy",
    "params": [ 89 ]
  },
```
  
7. If the ABN is valid you'll get 0 remainder.

```json
  {
    "method": "assertEquals",
    "params": [ 0 ]
  }
```

As the above shows this is straight forward.

Some of the more complex ones include states. Such an example is a LUHN where two states need to be compared (Nuix has a pretty good built in CC LUHN so not included). In such instances the following methods will help with this: saveState, loadState, addState, assertStateMatches

## Available Methods

Current methods are based on the algorithms I'm aware of at writing this. Methods are simplistic to write and expand upon and I'd be very happy to include more if needed.

Remember, if you need to parallel/fork your logic you are going to need states

For those who has used any sort of machine language these methods should be familiar

If at any point a FALSE or exception is returned the entity is considered invalid.

Function | Action | Params
------------ | ------------- | -------------
add | Math adds the param to the current input | Numeric
addArray | Adds each placement of the weight onto the input | Hash of weighted addition 
addState | Adds the saved state to the current input | state name
applyWeight | Multiplies each placement of the weight onto the input | Hash of weighted multiplication (use 0 to ignore field and state if you need to keep said value) 
assertEquals | Usually used as the last or basic check to confirm the input matches the expected value | expected value
assertEqualsAny | Used as a check to ensure that the value is within the expected values | array of possible expected values
assertNotEquals | Used as an inversion of assertEquals | banned value
assertStateMatches | Compares the current input to a known state | state containing expected value
changeCase | Convert the lettering to a particular case | "up", "down", "capitalize"
getElementAtPosition | Output the element from position in the supplied input array | index
joinStringArray | Join the input array by a particular char | char or empty string to join with no delimitator
loadState | Make the input become the saved state | saved state name
mapIntArrayToStringArray | A convenience method for substitueArray for known only int value arrays| an array of strings that can be converted to ints
modBy | Apply a modulus against the input and return the remainder | mod value
removeElements | Strip out any unwanted values, usually this is aesthetic padding you may find in its natural state | an array of values to be removed
saveState | Save the input against the specific name | specific name to call this state
splitIntoChunks | Split the input by the param | a single char, or no char to split into chars
substitueArray | Caesar cipher. Input is translated based on the provided two exactly the same sized arrays | two arrays of exactly the same size
sumArray | Add all the values in the input | an array of numbers



## License

```
Copyright 2020 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
