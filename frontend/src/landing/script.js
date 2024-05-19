let button = document.getElementById("button");
let bg = document.getElementById("bg");
let label = document.getElementById("label");

let logas = document.getElementById("logas");
let last = document.getElementById("last");


let hoverLink1 = document.getElementById("hoverLink1");
let hoverLink2 = document.getElementById("hoverLink2");
let hoverLink3 = document.getElementById("hoverLink3");
let hoverLink4 = document.getElementById("hoverLink4");
let hoverLink5 = document.getElementById("hoverLink5");



let icon = document.getElementsByClassName('icon')

let text = document.getElementsByClassName('text')
let logo = document.getElementsByClassName('logo')

let hoverImg = document.getElementsByClassName('hoverImg')

// ---------

logo[0].addEventListener("mouseenter", function( event ) {
    text[0].style.top = '88px'
    text[0].style.opacity = '1'
}, false);

logo[0].addEventListener("mouseleave", function( event ) {
    text[0].style.top = '-160px'
    text[0].style.opacity = '0'
}, false);

logo[1].addEventListener("mouseenter", function( event ) {
    text[1].style.top = '88px'
    text[1].style.opacity = '1'
}, false);

logo[1].addEventListener("mouseleave", function( event ) {
    text[1].style.top = '-160px'
    text[1].style.opacity = '0'
}, false);

logo[2].addEventListener("mouseenter", function( event ) {
    text[2].style.top = '88px'
     text[2].style.opacity = '1'
}, false);

logo[2].addEventListener("mouseleave", function( event ) {
    text[2].style.top = '-160px'
    text[2].style.opacity = '0'
}, false);

logo[3].addEventListener("mouseenter", function( event ) {
    text[3].style.top = '88px'
     text[3].style.opacity = '1'
}, false);

logo[3].addEventListener("mouseleave", function( event ) {
    text[3].style.top = '-160px'
    text[3].style.opacity = '0'
}, false);


// -------

hoverLink1.addEventListener("mouseenter", function( event ) {
    hoverImg[0].style.opacity = 1;

    icon[0].style.filter = 'invert(100%)';
}, false);

hoverLink1.addEventListener("mouseleave", function( event ) {
    hoverImg[0].style.opacity = 0;
    icon[0].style.filter = 'invert(0%)';
}, false);

hoverLink2.addEventListener("mouseenter", function( event ) {
    hoverImg[1].style.opacity = 1;
    icon[1].style.filter = 'invert(100%)';
}, false);

hoverLink2.addEventListener("mouseleave", function( event ) {
    hoverImg[1].style.opacity = 0;
    icon[1].style.filter = 'invert(0%)';
}, false);

hoverLink3.addEventListener("mouseenter", function( event ) {
    hoverImg[2].style.opacity = 1;
    icon[2].style.filter = 'invert(100%)';
}, false);

hoverLink3.addEventListener("mouseleave", function( event ) {
    hoverImg[2].style.opacity = 0;
    icon[2].style.filter = 'invert(0%)';
    
}, false);

hoverLink4.addEventListener("mouseenter", function( event ) {
    hoverImg[3].style.opacity = 1;
    icon[3].style.filter = 'invert(100%)';
}, false);

hoverLink4.addEventListener("mouseleave", function( event ) {
    hoverImg[3].style.opacity = 0;
    icon[3].style.filter = 'invert(0%)';
}, false);

hoverLink5.addEventListener("mouseenter", function( event ) {
    hoverImg[4].style.opacity = 1;
    icon[4].style.filter = 'invert(100%)';
}, false);

hoverLink5.addEventListener("mouseleave", function( event ) {
    hoverImg[4].style.opacity = 0;
    icon[4].style.filter = 'invert(0%)';
}, false);


// -------

button.addEventListener("mouseenter", function( event ) {
    bg.style.opacity = 1;
    bg.style.bottom = 0;
    label.style.opacity = 1;
}, false);

bg.addEventListener("mouseenter", function( event ) {
  bg.style.opacity = 0;
  bg.style.bottom = 'unset';
  label.style.opacity = 0;
}, false);

// ---------

logas.addEventListener("mouseenter", function( event ) {
    last.style.opacity = 0.1;
}, false);

logas.addEventListener("mouseleave", function( event ) {
  last.style.opacity = 1;
}, false);


function openLink()
{
  //window.location.href = 'https://ibo.quid.io';
  window.alert("Come back on May 4th, and may the force be with you.");
}